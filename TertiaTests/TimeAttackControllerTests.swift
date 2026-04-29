//
//  TimeAttackControllerTests.swift
//  TertiaTests
//
//  Created by Mark Martin on 4/29/26.
//

import Testing
import Foundation
@testable import Tertia

@Suite("TimeAttackController")
struct TimeAttackControllerTests {

    @Test("addTime extends remaining while running and tracks bonusGranted")
    func addTimeExtendsRemaining() {
        let controller = TimeAttackController(totalDuration: 90)
        controller.start()
        let before = controller.remaining

        let added = controller.addTime(3)

        #expect(added == 3)
        #expect(controller.bonusGranted == 3)
        #expect(controller.remaining > before)
        #expect(controller.remaining <= before + 3.01)  // small wall-clock slack
    }

    @Test("addTime caps total bonus at maxBonus per round")
    func addTimeRespectsCap() {
        let controller = TimeAttackController(totalDuration: 90)
        controller.start()

        // Ten +3s grants the whole 30s budget.
        for _ in 0..<10 {
            #expect(controller.addTime(3) == 3)
        }
        #expect(controller.bonusGranted == 30)

        // Eleventh attempt is fully rejected.
        let extra = controller.addTime(3)
        #expect(extra == 0)
        #expect(controller.bonusGranted == 30)
    }

    @Test("addTime partially fills when only some headroom remains")
    func addTimePartiallyFills() {
        let controller = TimeAttackController(totalDuration: 90)
        controller.start()

        // Burn 28s of bonus.
        for _ in 0..<9 { _ = controller.addTime(3) }
        _ = controller.addTime(1)
        #expect(controller.bonusGranted == 28)

        // Asking for 3 only grants the remaining 2.
        let added = controller.addTime(3)
        #expect(added == 2)
        #expect(controller.bonusGranted == 30)
    }

    @Test("addTime works while paused and survives resume")
    func addTimeWhilePausedAdjustsResumed() {
        let controller = TimeAttackController(totalDuration: 90)
        controller.start()
        controller.pause()
        let pausedBefore = controller.remaining

        let added = controller.addTime(3)
        #expect(added == 3)
        #expect(controller.remaining == pausedBefore + 3)

        controller.resume()
        // After resume, remaining should still reflect the bonus (within wall-clock slack).
        #expect(controller.remaining > pausedBefore + 2.5)
    }

    @Test("start resets bonusGranted")
    func startResetsBonus() {
        let controller = TimeAttackController(totalDuration: 90)
        controller.start()
        _ = controller.addTime(9)
        #expect(controller.bonusGranted == 9)

        controller.start()
        #expect(controller.bonusGranted == 0)
    }
}
