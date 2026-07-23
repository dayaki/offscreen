import Foundation

/// Pure scheduling math, kept free of AppKit so it is trivially testable.
enum BreakScheduleMath {
    /// Which kind the next break should be, given how many short breaks have
    /// completed since the last long one. `longBreakEvery == 0` disables
    /// long breaks entirely.
    static func nextBreakKind(shortBreaksSinceLong: Int, longBreakEvery: Int) -> BreakKind {
        guard longBreakEvery > 0 else { return .short }
        return shortBreaksSinceLong >= longBreakEvery - 1 ? .long : .short
    }

    static func duration(of kind: BreakKind, timing: TimingConfig) -> Int {
        switch kind {
        case .short: timing.shortBreakSeconds
        case .long: timing.longBreakSeconds
        case .planned(_, let duration): duration
        }
    }

    /// Work accrual value that makes the next break land `snoozeSeconds`
    /// from now. May go negative when the snooze exceeds the work interval.
    static func accruedAfterSnooze(workSeconds: Int, snoozeSeconds: Int) -> Double {
        Double(workSeconds) - Double(snoozeSeconds)
    }
}
