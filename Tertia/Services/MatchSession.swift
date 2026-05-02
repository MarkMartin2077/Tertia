//
//  MatchSession.swift
//  Tertia
//
//  High-level coordinator for an active versus match. Owns a MatchTransport,
//  encodes/decodes VersusMessage, runs heartbeats, and exposes a clean
//  surface to the game model layer (Phase 4: VersusGame).
//

import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "Mark.Tertia", category: "MatchSession")

/// Lifecycle state of a versus match. Starts at `.connecting` while the
/// transport hands us peer info; flips to `.active` once we know the remote
/// player and have started exchanging heartbeats. `.disconnected` is
/// terminal — the session shouldn't be reused after that.
enum MatchSessionState: Equatable, Sendable {
    case connecting
    case active
    case disconnected(reason: DisconnectReason)

    enum DisconnectReason: Equatable, Sendable {
        case peerLeft
        case peerSilent
        case localDisconnect
        case transportFailure(String)
    }
}

/// Tunable timings. Production defaults match the spec in VERSUS_PLAN.md;
/// tests pass dramatically shorter values so heartbeat / disconnect logic
/// can be exercised in milliseconds.
struct MatchSessionTimings: Sendable, Equatable {
    /// How often we send a `.heartbeat` to the peer.
    var heartbeatInterval: Duration
    /// How long we tolerate no incoming traffic before declaring the peer
    /// silent and emitting a disconnect.
    var disconnectGrace: Duration
    /// Polling interval for the watchdog. Doesn't need to match the grace
    /// window; smaller values give faster disconnect detection at the cost
    /// of more wakeups.
    var watchdogPoll: Duration

    nonisolated static let production = MatchSessionTimings(
        heartbeatInterval: .seconds(5),
        disconnectGrace: .seconds(20),
        watchdogPoll: .seconds(1)
    )

    nonisolated static let unitTest = MatchSessionTimings(
        heartbeatInterval: .milliseconds(50),
        disconnectGrace: .milliseconds(200),
        watchdogPoll: .milliseconds(20)
    )
}

@MainActor
@Observable
final class MatchSession {
    private let transport: MatchTransport
    private let timings: MatchSessionTimings
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let clock: @MainActor () -> Date

    /// Stream of decoded incoming messages. Consumers iterate this in a
    /// `for await` loop; the stream finishes when the session disconnects.
    let incoming: AsyncStream<VersusMessage>
    private let incomingContinuation: AsyncStream<VersusMessage>.Continuation

    private(set) var state: MatchSessionState = .connecting
    private(set) var localPlayerID: VersusPlayerID
    private(set) var remotePlayerID: VersusPlayerID?

    private var lastInboundAt: Date
    private var heartbeatTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var eventsTask: Task<Void, Never>?

    init(
        transport: MatchTransport,
        timings: MatchSessionTimings = .production,
        clock: @escaping @MainActor () -> Date = { .now }
    ) {
        self.transport = transport
        self.timings = timings
        self.clock = clock
        self.localPlayerID = transport.localPlayerID
        self.remotePlayerID = transport.remotePlayerID
        self.lastInboundAt = clock()

        var continuation: AsyncStream<VersusMessage>.Continuation!
        self.incoming = AsyncStream { continuation = $0 }
        self.incomingContinuation = continuation

        if remotePlayerID != nil {
            self.state = .active
        }
    }

    /// Call once after construction to wire up the long-running pumps. Kept
    /// as an explicit step so tests can construct a session, snapshot state,
    /// and only then activate the loops.
    func start() {
        guard receiveTask == nil else { return }
        receiveTask = Task { @MainActor [weak self] in
            await self?.pumpIncoming()
        }
        eventsTask = Task { @MainActor [weak self] in
            await self?.pumpConnectionEvents()
        }
        heartbeatTask = Task { @MainActor [weak self] in
            await self?.runHeartbeat()
        }
        watchdogTask = Task { @MainActor [weak self] in
            await self?.runWatchdog()
        }
    }

    /// Whether this peer is the host. Deterministic from playerID comparison
    /// so both peers compute the same answer without a handshake. Returns
    /// false until the remote peer is known.
    var isHost: Bool {
        guard let remote = remotePlayerID else { return false }
        return localPlayerID < remote
    }

    /// Encodes and sends a message to the peer. Failures (transport blip,
    /// transient GameKit error) are logged but do NOT tear down the session
    /// — a single send error is rarely terminal, and tearing down on the
    /// first failure means a momentary network hiccup ends an otherwise
    /// healthy match. Persistent failures get caught by the watchdog instead
    /// (no incoming traffic for `disconnectGrace` → `.peerSilent`).
    func send(_ message: VersusMessage) async {
        do {
            let data = try encoder.encode(message)
            try await transport.send(data, reliability: .reliable)
        } catch {
            logger.error("Send failed (\(String(describing: message))): \(error.localizedDescription)")
        }
    }

    /// Voluntarily ends the session. Idempotent.
    func leave() {
        transition(to: .disconnected(reason: .localDisconnect))
    }

    // MARK: - Pumps

    private func pumpIncoming() async {
        for await data in transport.incoming {
            lastInboundAt = clock()
            do {
                let message = try decoder.decode(VersusMessage.self, from: data)
                // Heartbeats only matter for the watchdog timestamp (already
                // updated above). Don't surface them to consumers — they're
                // pure transport plumbing.
                if case .heartbeat = message { continue }
                incomingContinuation.yield(message)
            } catch {
                // Malformed payload from the peer. Log + drop; we don't fail
                // the whole session over a single bad message.
                logger.error("Decode failed: \(error.localizedDescription)")
            }
        }
    }

    private func pumpConnectionEvents() async {
        for await event in transport.connectionEvents {
            switch event {
            case .connected(let id):
                if remotePlayerID == nil {
                    remotePlayerID = id
                }
                if state == .connecting {
                    transition(to: .active)
                }
            case .disconnected:
                transition(to: .disconnected(reason: .peerLeft))
            case .failed(let reason):
                transition(to: .disconnected(reason: .transportFailure(reason)))
            }
        }
    }

    private func runHeartbeat() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: timings.heartbeatInterval)
            } catch {
                return
            }
            guard case .active = state else { continue }
            // Heartbeats are pure keepalive; use unreliable mode so a
            // transient failure doesn't accumulate in GameKit's reliable
            // queue. Errors are swallowed silently — if heartbeats stop
            // arriving in BOTH directions, the watchdog catches it via
            // disconnectGrace.
            do {
                let data = try encoder.encode(VersusMessage.heartbeat(at: clock()))
                try await transport.send(data, reliability: .unreliable)
            } catch {
                logger.debug("Heartbeat send failed (transient): \(error.localizedDescription)")
            }
        }
    }

    private func runWatchdog() async {
        let graceSeconds = Self.seconds(from: timings.disconnectGrace)
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: timings.watchdogPoll)
            } catch {
                return
            }
            guard case .active = state else { continue }
            let elapsed = clock().timeIntervalSince(lastInboundAt)
            if elapsed >= graceSeconds {
                transition(to: .disconnected(reason: .peerSilent))
            }
        }
    }

    /// Converts a `Duration` to seconds as `Double`. `Duration.components`
    /// is `(seconds: Int64, attoseconds: Int64)`; we collapse both pieces
    /// into a `TimeInterval` for comparison with `Date` arithmetic.
    private static func seconds(from duration: Duration) -> TimeInterval {
        let parts = duration.components
        return TimeInterval(parts.seconds) + TimeInterval(parts.attoseconds) / 1_000_000_000_000_000_000
    }

    // MARK: - State machine

    private func transition(to next: MatchSessionState) {
        guard state != next else { return }
        // Once disconnected, ignore further transitions — terminal state.
        if case .disconnected = state { return }
        state = next
        if case .disconnected = next {
            heartbeatTask?.cancel()
            watchdogTask?.cancel()
            receiveTask?.cancel()
            eventsTask?.cancel()
            transport.disconnect()
            incomingContinuation.finish()
        }
    }
}
