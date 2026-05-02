//
//  PendingScoreQueueTests.swift
//  TertiaTests
//

import Foundation
import Testing
@testable import Tertia

@Suite("PendingScoreQueue")
struct PendingScoreQueueTests {

    @Test("Fresh queue is empty")
    func freshQueueIsEmpty() {
        let queue = PendingScoreQueue()
        #expect(queue.isEmpty)
        #expect(queue.entries.isEmpty)
    }

    @Test("enqueue stores a score for a new leaderboard")
    func enqueueStoresNew() {
        var queue = PendingScoreQueue()
        queue.enqueue(score: 12, for: "lb.a")
        #expect(queue.entries == ["lb.a": 12])
    }

    @Test("enqueue keeps the higher of two scores for the same leaderboard")
    func enqueueKeepsMax() {
        var queue = PendingScoreQueue()
        queue.enqueue(score: 8, for: "lb.a")
        queue.enqueue(score: 12, for: "lb.a")
        queue.enqueue(score: 5, for: "lb.a")
        #expect(queue.entries == ["lb.a": 12])
    }

    @Test("enqueue handles multiple leaderboards independently")
    func enqueueIsolatesLeaderboards() {
        var queue = PendingScoreQueue()
        queue.enqueue(score: 4, for: "lb.a")
        queue.enqueue(score: 9, for: "lb.b")
        #expect(queue.entries == ["lb.a": 4, "lb.b": 9])
    }

    @Test("enqueue rejects zero and negative scores")
    func enqueueRejectsNonPositive() {
        var queue = PendingScoreQueue()
        queue.enqueue(score: 0, for: "lb.a")
        queue.enqueue(score: -3, for: "lb.b")
        #expect(queue.isEmpty)
    }

    @Test("drain returns the snapshot and empties the queue")
    func drainReturnsAndEmpties() {
        var queue = PendingScoreQueue()
        queue.enqueue(score: 10, for: "lb.a")
        queue.enqueue(score: 20, for: "lb.b")
        let snapshot = queue.drain()
        #expect(snapshot == ["lb.a": 10, "lb.b": 20])
        #expect(queue.isEmpty)
    }

    @Test("reenqueue restores failed items, max-coalescing against newer ones")
    func reenqueueCoalesces() {
        var queue = PendingScoreQueue()
        queue.enqueue(score: 8, for: "lb.a")
        // While the snapshot was in flight, a higher score landed.
        queue.enqueue(score: 15, for: "lb.a")
        // Failed snapshot tries to come back with the lower 8 — should NOT
        // overwrite the in-queue 15.
        queue.reenqueue(["lb.a": 8])
        #expect(queue.entries == ["lb.a": 15])
    }

    @Test("reenqueue brings back entries that were drained empty")
    func reenqueueRestoresAfterDrain() {
        var queue = PendingScoreQueue()
        queue.enqueue(score: 10, for: "lb.a")
        let snapshot = queue.drain()
        #expect(queue.isEmpty)
        queue.reenqueue(snapshot)
        #expect(queue.entries == ["lb.a": 10])
    }
}
