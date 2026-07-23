import Testing
@testable import Offscreen

@Suite struct IdleTests {
    private func makeEngine() -> BreakEngine {
        let timing = TimingConfig(
            workSeconds: 100, shortBreakSeconds: 10, longBreakEvery: 3,
            longBreakSeconds: 30, leadTimeSeconds: 20, snoozeLimitPerCycle: 2
        )
        return BreakEngine(timing: timing, clock: EngineClock(timeScale: 1))
    }

    @Test func idlePauseStopsAccrual() {
        let engine = makeEngine()
        engine.advance(by: 50)
        engine.enterIdlePause()
        #expect(engine.phase == .idlePaused)
        engine.advance(by: 500)
        #expect(engine.workAccrued == 50) // nothing accrued while idle
    }

    @Test func shortAbsenceResumesCycle() {
        let engine = makeEngine()
        engine.advance(by: 50)
        engine.enterIdlePause()
        engine.exitIdlePause(afterRealSecondsAway: 5) // < 10s break duration
        #expect(engine.phase == .working)
        #expect(engine.workAccrued == 50)
    }

    @Test func longAbsenceCountsAsBreak() {
        let engine = makeEngine()
        engine.advance(by: 50)
        engine.enterIdlePause()
        engine.exitIdlePause(afterRealSecondsAway: 15) // ≥ 10s short break
        #expect(engine.phase == .working)
        #expect(engine.workAccrued == 0)
        #expect(engine.shortBreaksSinceLong == 1) // cadence advanced
    }

    @Test func absenceReturnsToPreBreakInsideLeadWindow() {
        let engine = makeEngine()
        engine.advance(by: 85) // inside 20s lead window
        #expect(engine.phase == .preBreak)
        engine.enterIdlePause()
        engine.exitIdlePause(afterRealSecondsAway: 3)
        #expect(engine.phase == .preBreak)
    }

    @Test func noIdlePauseDuringBreak() {
        let engine = makeEngine()
        engine.advance(by: 101)
        #expect(engine.phase == .inBreak)
        engine.enterIdlePause() // must be a no-op mid-break
        #expect(engine.phase == .inBreak)
    }
}
