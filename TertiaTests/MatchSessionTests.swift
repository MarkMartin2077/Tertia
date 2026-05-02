//
//  MatchSessionTests.swift
//  TertiaTests
//
//  Exercises MatchSession against the in-memory StubMatchTransport so we
//  can validate decode/encode, heartbeat scheduling, watchdog disconnect,
//  and host-election logic without touching GameKit.
//

import Foundation
import Testing
@testable import Tertia

/// Heartbeat / watchdog tests are time-sensitive and starve each other
/// when run in parallel on the same MainActor — `.serialized` runs them
/// one at a time so the 20ms intervals stay reliable.
@Suite("MatchSession", .serialized)
@MainActor
struct MatchSessionTests {

    private static let timings = MatchSessionTimings.unitTest

    private func makePair() -> (host: StubMatchTransport, guest: StubMatchTransport) {
        // Lex order: "P-1" < "P-2", so P-1 is host. We explicitly pick IDs
        // that exercise the deterministic comparison.
        let host = StubMatchTransport(localPlayerID: "P-1", remotePlayerID: "P-2")
        let guest = StubMatchTransport(localPlayerID: "P-2", remotePlayerID: "P-1")
        return (host, guest)
    }

    private func encode(_ message: VersusMessage) throws -> Data {
        try JSONEncoder().encode(message)
    }

    @Test("Host election is deterministic from lexicographic playerID order")
    func hostElectionDeterministic() {
        let (hostTransport, guestTransport) = makePair()
        let hostSession = MatchSession(transport: hostTransport, timings: Self.timings)
        let guestSession = MatchSession(transport: guestTransport, timings: Self.timings)
        #expect(hostSession.isHost)
        #expect(!guestSession.isHost)
    }

    @Test("Outbound messages are JSON-encoded onto the transport")
    func sendEncodes() async throws {
        let (transport, _) = makePair()
        let session = MatchSession(transport: transport, timings: Self.timings)
        await session.send(.deckSeed(42))

        #expect(transport.sentPayloads.count == 1)
        let decoded = try JSONDecoder().decode(VersusMessage.self, from: transport.sentPayloads[0])
        #expect(decoded == .deckSeed(42))
    }

    @Test("Inbound payloads decode and surface on the incoming stream")
    func receiveDecodesAndSurfaces() async throws {
        let (transport, _) = makePair()
        let session = MatchSession(transport: transport, timings: Self.timings)
        session.start()

        let payload = try encode(.forfeit(by: "P-2"))
        transport.deliverIncoming(payload)

        var iterator = session.incoming.makeAsyncIterator()
        let received = await iterator.next()
        #expect(received == .forfeit(by: "P-2"))
    }

    @Test("Heartbeats are NOT surfaced to consumers — they stay in the transport layer")
    func heartbeatsAreFiltered() async throws {
        let (transport, _) = makePair()
        let session = MatchSession(transport: transport, timings: Self.timings)
        session.start()

        // Deliver a heartbeat first, then a meaningful message. The consumer
        // should only see the meaningful one.
        transport.deliverIncoming(try encode(.heartbeat(at: .now)))
        transport.deliverIncoming(try encode(.deckSeed(7)))

        var iterator = session.incoming.makeAsyncIterator()
        let first = await iterator.next()
        #expect(first == .deckSeed(7))
    }

    @Test("Heartbeat task sends periodic heartbeats while active")
    func heartbeatTaskFires() async throws {
        let (transport, _) = makePair()
        let session = MatchSession(transport: transport, timings: Self.timings)
        session.start()

        // unitTest interval is 50ms; sleep ~180ms and we should see ≥2 heartbeats.
        try await Task.sleep(for: .milliseconds(180))

        let heartbeatCount = transport.sentPayloads
            .compactMap { try? JSONDecoder().decode(VersusMessage.self, from: $0) }
            .filter {
                if case .heartbeat = $0 { return true }
                return false
            }
            .count
        #expect(heartbeatCount >= 2)
    }

    @Test("Watchdog declares the peer silent after the disconnect grace passes")
    func watchdogFiresAfterSilence() async throws {
        let (transport, _) = makePair()
        let session = MatchSession(transport: transport, timings: Self.timings)
        session.start()

        // Don't deliver anything to the transport. Wait past the 200ms grace.
        try await Task.sleep(for: .milliseconds(350))

        if case .disconnected(let reason) = session.state {
            #expect(reason == .peerSilent)
        } else {
            Issue.record("Expected disconnect after silence; state = \(session.state)")
        }
    }

    @Test("Inbound traffic resets the watchdog window")
    func inboundResetsWatchdog() async throws {
        let (transport, _) = makePair()
        let session = MatchSession(transport: transport, timings: Self.timings)
        session.start()

        // Steadily feed messages so the watchdog never crosses the 200ms grace.
        for _ in 0..<8 {
            transport.deliverIncoming(try encode(.heartbeat(at: .now)))
            try await Task.sleep(for: .milliseconds(50))
        }

        // Should still be active (total elapsed ~400ms but each delivery within 50ms < 200ms grace).
        if case .active = session.state {
            // happy path
        } else {
            Issue.record("Expected still-active session; state = \(session.state)")
        }
    }

    @Test("Transport disconnect event flips session to disconnected(.peerLeft)")
    func transportDisconnectFlipsState() async throws {
        let (transport, _) = makePair()
        let session = MatchSession(transport: transport, timings: Self.timings)
        session.start()

        transport.emitEvent(.disconnected("P-2"))

        // Give the events pump a tick to process.
        try await Task.sleep(for: .milliseconds(10))
        if case .disconnected(let reason) = session.state {
            #expect(reason == .peerLeft)
        } else {
            Issue.record("Expected disconnected(.peerLeft); state = \(session.state)")
        }
    }

    @Test("leave() flips state to disconnected(.localDisconnect) and is idempotent")
    func leaveIsIdempotent() {
        let (transport, _) = makePair()
        let session = MatchSession(transport: transport, timings: Self.timings)
        session.leave()
        if case .disconnected(let reason) = session.state {
            #expect(reason == .localDisconnect)
        } else {
            Issue.record("Expected disconnected(.localDisconnect)")
        }
        // Second call is a no-op — terminal state shouldn't transition further.
        session.leave()
        if case .disconnected(let reason) = session.state {
            #expect(reason == .localDisconnect)
        }
    }
}
