//
//  GameCenterServiceTests.swift
//  TertiaTests
//
//  Integration tests for the small bits of GameCenterService logic that
//  don't depend on Apple's GameKit servers — primarily the in-memory retry
//  queue. Anything that requires a real authenticated GKLocalPlayer is
//  skipped here because there's no headless way to fake one.
//

import Foundation
import Testing
@testable import Tertia

@Suite("GameCenterService")
@MainActor
struct GameCenterServiceTests {

    @Test("Time Attack submission while unauthenticated lands in the retry queue")
    func timeAttackSubmissionQueuesWhenOffline() async {
        let service = GameCenterService()
        // No authentication has happened — isAuthenticated is false.
        await service.submitTimeAttackScore(14)

        #expect(service.pendingScores.entries == [LeaderboardID.timeAttackBest: 14])
    }

    @Test("Daily score and streak submissions queue independently")
    func dailySubmissionsQueueIndependently() async {
        let service = GameCenterService()
        await service.submitDailyScore(7)
        await service.submitBestStreak(5)

        #expect(service.pendingScores.entries[LeaderboardID.dailyScoreToday] == 7)
        #expect(service.pendingScores.entries[LeaderboardID.dailyStreakBest] == 5)
        #expect(service.pendingScores.entries.count == 2)
    }

    @Test("Repeat submissions for the same leaderboard keep the highest")
    func repeatSubmissionsCoalesce() async {
        let service = GameCenterService()
        await service.submitTimeAttackScore(8)
        await service.submitTimeAttackScore(15)
        await service.submitTimeAttackScore(11)

        #expect(service.pendingScores.entries == [LeaderboardID.timeAttackBest: 15])
    }

    @Test("Zero scores are dropped, never queued")
    func zeroScoresIgnored() async {
        let service = GameCenterService()
        await service.submitTimeAttackScore(0)
        #expect(service.pendingScores.isEmpty)
    }

    @Test("drainPendingScoreSubmissions is a no-op while unauthenticated")
    func drainNoOpWhileUnauthenticated() async {
        let service = GameCenterService()
        await service.submitTimeAttackScore(9)

        // Manually invoke drain — no auth, so the queue must be left intact.
        await service.drainPendingScoreSubmissions()

        #expect(service.pendingScores.entries[LeaderboardID.timeAttackBest] == 9)
    }
}
