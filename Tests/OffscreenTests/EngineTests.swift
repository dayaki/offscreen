import Testing
import Foundation
@testable import Offscreen

@Suite struct EngineTests {
    private func makeEngine(
        work: Int = 100, short: Int = 10, longEvery: Int = 3, long: Int = 30,
        lead: Int = 20, snoozeLimit: Int = 2
    ) -> BreakEngine {
        let timing = TimingConfig(
            workSeconds: work, shortBreakSeconds: short, longBreakEvery: longEvery,
            longBreakSeconds: long, leadTimeSeconds: lead, snoozeLimitPerCycle: snoozeLimit
        )
        return BreakEngine(timing: timing, clock: EngineClock(timeScale: 1))
    }

    @Test func fullCycle() {
        let engine = makeEngine()
        #expect(engine.phase == .working)

        engine.advance(by: 79)
        #expect(engine.phase == .working)

        engine.advance(by: 2) // 81s accrued, lead window is last 20s
        #expect(engine.phase == .preBreak)

        engine.advance(by: 20) // due
        #expect(engine.phase == .inBreak)
        #expect(engine.activeBreak == .short)

        engine.advance(by: 10) // break over
        #expect(engine.phase == .working)
        #expect(engine.workAccrued == 0)
        #expect(engine.shortBreaksSinceLong == 1)
    }

    @Test func thirdBreakIsLong() {
        let engine = makeEngine()
        for expected in [BreakKind.short, .short, .long] {
            engine.advance(by: 101)
            #expect(engine.activeBreak == expected)
            engine.advance(by: 31) // longest break duration, ends either kind
        }
        #expect(engine.shortBreaksSinceLong == 0) // long break reset the cadence
    }

    @Test func snoozePushesBreakBack() {
        let engine = makeEngine()
        engine.advance(by: 85)
        #expect(engine.phase == .preBreak)

        engine.snooze(seconds: 50)
        #expect(engine.phase == .working)
        #expect(abs(engine.timeUntilBreak - 50) < 0.001)
        #expect(engine.snoozesRemaining == 1)

        // Limit of 2: third snooze is a no-op.
        engine.advance(by: 40)
        engine.snooze(seconds: 50)
        #expect(engine.snoozesRemaining == 0)
        engine.advance(by: 40)
        let before = engine.timeUntilBreak
        engine.snooze(seconds: 50)
        #expect(engine.timeUntilBreak == before)
    }

    @Test func skipDoesNotAdvanceCadence() {
        let engine = makeEngine()
        engine.advance(by: 101)
        #expect(engine.phase == .inBreak)
        engine.skipBreak()
        #expect(engine.phase == .working)
        #expect(engine.shortBreaksSinceLong == 0) // skipped breaks don't count
        #expect(engine.workAccrued == 0)
    }

    @Test func holdDefersBreak() {
        let engine = makeEngine()
        engine.setHold(.camera, active: true)
        engine.advance(by: 101)
        #expect(engine.phase == .holding)

        engine.advance(by: 60)
        #expect(engine.phase == .holding) // still held

        engine.setHold(.camera, active: false)
        engine.advance(by: 1)
        #expect(engine.phase == .inBreak)
    }

    @Test func holdSuppressesPreBreakPanel() {
        let engine = makeEngine() // work 100, lead 20
        engine.setHold(.microphone, active: true)
        engine.advance(by: 85) // inside the lead window, but held
        #expect(engine.phase == .working) // no heads-up panel while held

        engine.setHold(.microphone, active: false)
        engine.advance(by: 1)
        #expect(engine.phase == .preBreak) // panel appears once the hold clears
    }

    @Test func holdDuringPreBreakHidesPanel() {
        let engine = makeEngine()
        engine.advance(by: 85)
        #expect(engine.phase == .preBreak) // heads-up showing

        engine.setHold(.microphone, active: true)
        engine.advance(by: 1)
        #expect(engine.phase == .working) // a hold mid-heads-up pulls it back down
    }

    @Test func pauseAndResume() {
        let engine = makeEngine()
        engine.advance(by: 50)
        engine.pause(until: nil)
        #expect(engine.phase.isInactive)
        engine.advance(by: 500)
        #expect(engine.phase.isInactive) // no break while paused
        engine.resume()
        #expect(engine.phase == .working)
        #expect(engine.workAccrued == 0)
    }

    @Test func startBreakNowAndEndEarly() {
        let engine = makeEngine()
        engine.advance(by: 10)
        engine.startBreakNow()
        #expect(engine.phase == .inBreak)
        engine.endBreakEarly()
        #expect(engine.phase == .working)
        #expect(engine.shortBreaksSinceLong == 1) // ended-early still counts as taken
    }

    @Test func plannedBreakPreempts() {
        let engine = makeEngine()
        engine.pendingPlannedBreak = .planned(name: "Lunch", durationSeconds: 60)
        engine.advance(by: 101)
        #expect(engine.activeBreak == .planned(name: "Lunch", durationSeconds: 60))
        engine.advance(by: 61)
        #expect(engine.phase == .working)
        #expect(engine.pendingPlannedBreak == nil)
    }

    @Test func plannedBreakDoesNotSurviveCycleReset() {
        let engine = makeEngine()
        engine.pendingPlannedBreak = .planned(name: "Lunch", durationSeconds: 60)

        // Absorbed by a long absence (slept through it) → must not refire.
        engine.enterIdlePause()
        engine.exitIdlePause(afterRealSecondsAway: 120)
        #expect(engine.pendingPlannedBreak == nil)
        #expect(engine.nextBreakKind == .short)

        // Skipped from the pre-break panel → must not come back either.
        engine.pendingPlannedBreak = .planned(name: "Walk", durationSeconds: 60)
        engine.advance(by: 85)
        #expect(engine.phase == .preBreak)
        engine.skipBreak()
        #expect(engine.pendingPlannedBreak == nil)
    }
}
