import Testing
@testable import Offscreen

@Suite struct ScheduleMathTests {
    @Test func longBreakCadence() {
        // Every 3rd break long: after 0 and 1 shorts → short, after 2 → long.
        #expect(BreakScheduleMath.nextBreakKind(shortBreaksSinceLong: 0, longBreakEvery: 3) == .short)
        #expect(BreakScheduleMath.nextBreakKind(shortBreaksSinceLong: 1, longBreakEvery: 3) == .short)
        #expect(BreakScheduleMath.nextBreakKind(shortBreaksSinceLong: 2, longBreakEvery: 3) == .long)
        #expect(BreakScheduleMath.nextBreakKind(shortBreaksSinceLong: 5, longBreakEvery: 3) == .long)
    }

    @Test func longBreaksDisabled() {
        #expect(BreakScheduleMath.nextBreakKind(shortBreaksSinceLong: 99, longBreakEvery: 0) == .short)
    }

    @Test func durations() {
        let timing = TimingConfig.balanced
        #expect(BreakScheduleMath.duration(of: .short, timing: timing) == timing.shortBreakSeconds)
        #expect(BreakScheduleMath.duration(of: .long, timing: timing) == timing.longBreakSeconds)
        #expect(BreakScheduleMath.duration(of: .planned(name: "Lunch", durationSeconds: 1800), timing: timing) == 1800)
    }

    @Test func snoozeMath() {
        // 20 min interval, snooze 5 min → 15 min already "accrued".
        #expect(BreakScheduleMath.accruedAfterSnooze(workSeconds: 1200, snoozeSeconds: 300) == 900)
        // Snooze longer than the interval goes negative (break in 15 min regardless).
        #expect(BreakScheduleMath.accruedAfterSnooze(workSeconds: 600, snoozeSeconds: 900) == -300)
    }
}
