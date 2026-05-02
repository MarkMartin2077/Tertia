//
//  VersusMessageTests.swift
//  TertiaTests
//

import Foundation
import Testing
@testable import Tertia

@Suite("VersusMessage")
struct VersusMessageTests {

    private func roundTrip(_ message: VersusMessage) throws -> VersusMessage {
        let data = try JSONEncoder().encode(message)
        return try JSONDecoder().decode(VersusMessage.self, from: data)
    }

    @Test("deckSeed round-trips")
    func deckSeedRoundTrips() throws {
        let original: VersusMessage = .deckSeed(0xDEADBEEFCAFEBABE)
        #expect(try roundTrip(original) == original)
    }

    private func sampleWireCards(_ count: Int = 3) -> [WireCard] {
        let attrs: [(CardShape, CardCount, CardColor, CardFill)] = [
            (.circle, .one, .red, .filled),
            (.square, .two, .green, .empty),
            (.triangle, .three, .blue, .rightHalf),
            (.circle, .three, .green, .filled)
        ]
        return attrs.prefix(count).map {
            WireCard(shape: $0.0, count: $0.1, color: $0.2, fill: $0.3)
        }
    }

    @Test("claim preserves cards, date, and claimID")
    func claimRoundTrips() throws {
        let claimID = UUID()
        let when = Date(timeIntervalSince1970: 1_715_000_000)
        let original: VersusMessage = .claim(cards: sampleWireCards(), at: when, claimID: claimID)
        #expect(try roundTrip(original) == original)
    }

    @Test("claimResult preserves all fields including claimID")
    func claimResultRoundTrips() throws {
        let claimID = UUID()
        let original: VersusMessage = .claimResult(
            winner: "PLAYER-A",
            cards: sampleWireCards(),
            success: true,
            hostScore: 12,
            guestScore: 9,
            hostTrios: 4,
            guestTrios: 3,
            claimID: claimID
        )
        #expect(try roundTrip(original) == original)
    }

    @Test("dealThreeRequest and ack round-trip")
    func dealThreeRoundTrips() throws {
        let req: VersusMessage = .dealThreeRequest(by: "PLAYER-B")
        let ack: VersusMessage = .dealThreeAck(newCards: sampleWireCards())
        #expect(try roundTrip(req) == req)
        #expect(try roundTrip(ack) == ack)
    }

    @Test("WireCard resolves back to a SetCard with matching attributes")
    func wireCardRoundTripsViaResolve() {
        let card = SetCard(shape: .triangle, count: .two, color: .red, fill: .empty)
        let wire = card.wire
        let board = [
            SetCard(shape: .circle, count: .one, color: .blue, fill: .filled),
            card,
            SetCard(shape: .square, count: .three, color: .green, fill: .rightHalf)
        ]
        let resolved = wire.resolve(in: board)
        #expect(resolved == card)
    }

    @Test("forfeit round-trips")
    func forfeitRoundTrips() throws {
        let original: VersusMessage = .forfeit(by: "PLAYER-A")
        #expect(try roundTrip(original) == original)
    }

    @Test("matchConfirmation round-trips both accept and decline")
    func matchConfirmationRoundTrips() throws {
        let accept: VersusMessage = .matchConfirmation(by: "PLAYER-A", accepted: true)
        let decline: VersusMessage = .matchConfirmation(by: "PLAYER-B", accepted: false)
        #expect(try roundTrip(accept) == accept)
        #expect(try roundTrip(decline) == decline)
    }

    @Test("rematchRequest and rematchDecline round-trip")
    func rematchMessagesRoundTrip() throws {
        let req: VersusMessage = .rematchRequest(by: "PLAYER-A")
        let decline: VersusMessage = .rematchDecline(by: "PLAYER-B")
        #expect(try roundTrip(req) == req)
        #expect(try roundTrip(decline) == decline)
    }

    @Test("heartbeat round-trips")
    func heartbeatRoundTrips() throws {
        let original: VersusMessage = .heartbeat(at: Date(timeIntervalSince1970: 1_715_000_001))
        #expect(try roundTrip(original) == original)
    }

    @Test("Decoding garbage throws rather than producing a stray case")
    func malformedPayloadThrows() {
        let junk = Data([0x00, 0x01, 0x02])
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(VersusMessage.self, from: junk)
        }
    }
}
