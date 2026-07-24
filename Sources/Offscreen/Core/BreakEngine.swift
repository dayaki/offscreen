import AppKit
import Observation

/// The break scheduler state machine. Driven by a 4 Hz main-runloop timer;
/// each tick measures real elapsed time with a monotonic clock (clamped so
/// sleep/suspension can't be mistaken for work) and advances the state.
@Observable
final class BreakEngine {
    // MARK: Observable state

    private(set) var phase: EnginePhase = .working
    private(set) var workAccrued: Double = 0
    private(set) var shortBreaksSinceLong = 0
    private(set) var snoozesThisCycle = 0
    private(set) var activeBreak: BreakKind?
    private(set) var breakDuration: Double = 0
    private(set) var breakElapsed: Double = 0
    private(set) var holdReasons: Set<HoldReason> = []

    var timing: TimingConfig
    var behavior = BehaviorConfig()
    var customShortMessages: [String] = []
    var customLongMessages: [String] = []
    private(set) var breakMessage = ""

    // MARK: Derived

    var timeUntilBreak: Double { Double(timing.workSeconds) - workAccrued }
    var breakRemaining: Double { max(0, breakDuration - breakElapsed) }
    var breakProgress: Double { breakDuration > 0 ? breakRemaining / breakDuration : 0 }
    var snoozesRemaining: Int { max(0, timing.snoozeLimitPerCycle - snoozesThisCycle) }
    var nextBreakKind: BreakKind {
        pendingPlannedBreak ?? BreakScheduleMath.nextBreakKind(
            shortBreaksSinceLong: shortBreaksSinceLong,
            longBreakEvery: timing.longBreakEvery
        )
    }

    /// Set by the planned-break scheduler to make the next due break a named one.
    var pendingPlannedBreak: BreakKind?

    /// Whether the overlay's skip control is currently usable (difficulty-gated).
    var canSkipOverlay: Bool {
        guard phase == .inBreak else { return true }
        switch behavior.difficulty {
        case .casual: return true
        case .balanced: return breakElapsed >= Double(behavior.skipEnableDelaySeconds)
        case .hardcore: return false
        }
    }

    var canEndEarlyNow: Bool {
        guard let minimum = behavior.endEarlyMinimumSeconds, phase == .inBreak else { return false }
        return breakElapsed >= Double(minimum)
    }

    /// Holds that mean you're genuinely busy or away — a meeting (camera or
    /// mic), media, a shared screen, a fullscreen app, or a focus app. Like
    /// idle, these pause the work countdown: a break never lands mid-meeting
    /// and never fires the instant you're free. `.typing`/`.snoozed` are
    /// break-timing mechanics, not "busy", so they don't freeze the clock.
    private var isBusyHeld: Bool {
        holdReasons.contains { $0 != .typing && $0 != .snoozed }
    }

    /// The countdown is frozen because a busy hold is active while you'd
    /// otherwise be working toward a break. Drives the menu bar's paused state.
    var isPausedByHold: Bool {
        (phase == .working || phase == .preBreak) && isBusyHeld
    }

    // MARK: Internals

    let clock: EngineClock
    private var lastTick: ContinuousClock.Instant
    private var timer: Timer?
    private var activityToken: NSObjectProtocol?
    private var listeners: [(EngineEvent) -> Void] = []

    init(timing: TimingConfig = .balanced, clock: EngineClock = EngineClock()) {
        self.timing = timing
        self.clock = clock
        self.lastTick = clock.now
    }

    func addListener(_ listener: @escaping (EngineEvent) -> Void) {
        listeners.append(listener)
    }

    private func emit(_ event: EngineEvent) {
        for listener in listeners { listener(event) }
    }

    // MARK: Lifecycle

    func start() {
        guard timer == nil else { return }
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated],
            reason: "Break timing must not be App Napped"
        )
        lastTick = clock.now
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            // Main-runloop timers always fire on the main thread.
            MainActor.assumeIsolated { self?.timerFired() }
        }
        t.tolerance = 0.05
        RunLoop.main.add(t, forMode: .common)
        timer = t
        Log.engine.info("engine started, timeScale=\(self.clock.timeScale)")
    }

    private func timerFired() {
        let now = clock.now
        let realDelta = lastTick.duration(to: now).seconds
        lastTick = now
        // A large delta means we were suspended (sleep, debugger, App Nap
        // hiccup) — that gap was not work. Sleep/wake handling is separate.
        let capped = min(max(realDelta, 0), 5)
        advance(by: capped * clock.timeScale)
    }

    // MARK: State machine

    /// Advance the machine by `delta` virtual seconds. Public so tests can
    /// drive time directly without the runloop timer.
    func advance(by delta: Double) {
        switch phase {
        case .inactive(let reason):
            if case .paused(let until?) = reason, Date() >= until {
                resume()
            }

        case .working:
            if !isBusyHeld { workAccrued += delta } // a meeting/media/etc. pauses the clock
            if timeUntilBreak <= 0 {
                tryStartBreak()
            } else if timeUntilBreak <= Double(timing.leadTimeSeconds), holdReasons.isEmpty {
                // Only raise the heads-up when nothing is holding — no panel
                // popping up mid-meeting, media, screen share, etc.
                setPhase(.preBreak)
                emit(.preBreakStarted(kind: nextBreakKind))
            }

        case .preBreak:
            if !isBusyHeld { workAccrued += delta }
            if !holdReasons.isEmpty {
                // A hold began during the heads-up (e.g. joined a huddle) —
                // pull the panel back down and wait it out.
                setPhase(.working)
            } else if timeUntilBreak <= 0 {
                tryStartBreak()
            } else if timeUntilBreak > Double(timing.leadTimeSeconds) {
                // Snooze pushed the due time back out past the lead window.
                setPhase(.working)
            }

        case .holding:
            workAccrued += delta
            if holdReasons.isEmpty {
                startBreak(nextBreakKind)
            }

        case .inBreak:
            breakElapsed += delta
            if breakRemaining <= 0 {
                endBreak(.completed)
            }

        case .idlePaused:
            break
        }
        emit(.tick)
    }

    private func tryStartBreak() {
        if holdReasons.isEmpty {
            startBreak(nextBreakKind)
        } else if phase != .holding {
            setPhase(.holding)
        }
    }

    private func startBreak(_ kind: BreakKind) {
        activeBreak = kind
        breakDuration = Double(BreakScheduleMath.duration(of: kind, timing: timing))
        breakElapsed = 0
        breakMessage = BreakMessages.random(
            for: kind, customShort: customShortMessages, customLong: customLongMessages
        )
        if case .planned = kind { pendingPlannedBreak = nil }
        setPhase(.inBreak)
        emit(.breakStarted(kind: kind))
        Log.engine.info("break started: \(kind.title, privacy: .public)")
    }

    private func endBreak(_ reason: BreakEndReason) {
        guard let kind = activeBreak else { return }
        let elapsed = breakElapsed
        activeBreak = nil
        resetCycle(afterCompleted: reason != .skipped ? kind : nil)
        setPhase(.working)
        emit(.breakEnded(kind: kind, reason: reason, elapsedSeconds: elapsed))
        Log.engine.info("break ended: \(kind.title, privacy: .public) (\(String(describing: reason), privacy: .public))")
    }

    /// Reset the work cycle. Pass the completed break kind to advance the
    /// long-break cadence; nil (skip) leaves the cadence where it was.
    private func resetCycle(afterCompleted kind: BreakKind?) {
        workAccrued = 0
        snoozesThisCycle = 0
        holdReasons.remove(.snoozed)
        // A pending planned break never survives a cycle reset — whether it
        // was taken, skipped, or absorbed by an absence, it must not come
        // back as the next cycle's break.
        pendingPlannedBreak = nil
        switch kind {
        case .short: shortBreaksSinceLong += 1
        case .long: shortBreaksSinceLong = 0
        default: break
        }
    }

    private func setPhase(_ new: EnginePhase) {
        guard new != phase else { return }
        let old = phase
        phase = new
        emit(.phaseChanged(old: old, new: new))
        Log.engine.info("phase \(String(describing: old), privacy: .public) → \(String(describing: new), privacy: .public)")
    }

    // MARK: User actions

    func startBreakNow() {
        guard !phase.isInactive, phase != .inBreak else { return }
        startBreak(nextBreakKind)
    }

    /// Skip the upcoming (pre-break) or current break and restart the cycle.
    func skipBreak() {
        switch phase {
        case .inBreak:
            guard let kind = activeBreak else { return }
            let elapsed = breakElapsed
            activeBreak = nil
            resetCycle(afterCompleted: nil)
            setPhase(.working)
            emit(.breakEnded(kind: kind, reason: .skipped, elapsedSeconds: elapsed))
        case .preBreak, .holding:
            let kind = nextBreakKind
            resetCycle(afterCompleted: nil)
            setPhase(.working)
            emit(.breakEnded(kind: kind, reason: .skipped, elapsedSeconds: 0))
        default:
            break
        }
    }

    func endBreakEarly() {
        guard phase == .inBreak else { return }
        endBreak(.endedEarly)
    }

    func snooze(seconds: Int) {
        guard phase == .preBreak || phase == .holding, snoozesRemaining > 0 else { return }
        workAccrued = BreakScheduleMath.accruedAfterSnooze(
            workSeconds: timing.workSeconds, snoozeSeconds: seconds
        )
        snoozesThisCycle += 1
        // Stay in preBreak when the snooze lands inside the lead window so the
        // panel doesn't flicker away and back.
        if timeUntilBreak > Double(timing.leadTimeSeconds) {
            setPhase(.working)
        } else if phase == .holding {
            setPhase(.preBreak)
        }
        emit(.snoozed(seconds: seconds, used: snoozesThisCycle, limit: timing.snoozeLimitPerCycle))
    }

    func pause(until: Date?) {
        if phase == .inBreak { skipBreak() }
        setPhase(.inactive(.paused(until: until)))
    }

    func resume() {
        guard phase.isInactive else { return }
        workAccrued = 0
        snoozesThisCycle = 0
        setPhase(.working)
    }

    // MARK: Scheduling hooks

    /// Office hours boundary. Never overrides a manual pause.
    func setOfficeHoursActive(_ within: Bool) {
        if within {
            if case .inactive(.outsideOfficeHours) = phase { resume() }
        } else {
            guard !phase.isInactive else { return }
            if phase == .inBreak { skipBreak() }
            setPhase(.inactive(.outsideOfficeHours))
        }
    }

    /// A planned break's lead window begins now: the next due break becomes
    /// the named one and the normal pre-break flow (panel, snoozes, holds)
    /// takes it from here.
    func startPlannedBreakCountdown(_ kind: BreakKind) {
        guard case .planned = kind, !phase.isInactive, phase != .inBreak else { return }
        guard pendingPlannedBreak != kind else { return } // already counting down
        pendingPlannedBreak = kind
        workAccrued = Double(timing.workSeconds) - Double(timing.leadTimeSeconds)
        if phase == .idlePaused { setPhase(.preBreak) }
    }

    // MARK: Smart Pause hooks

    /// Stop accruing work time (user idle, asleep, or screen locked).
    func enterIdlePause() {
        guard phase == .working || phase == .preBreak || phase == .holding else { return }
        setPhase(.idlePaused)
    }

    /// User is back. A long enough absence counts as the next break taken;
    /// a short one just resumes the cycle where it left off.
    func exitIdlePause(afterRealSecondsAway gap: Double) {
        guard phase == .idlePaused else { return }
        let virtualGap = gap * clock.timeScale
        let kind = nextBreakKind
        let needed = Double(BreakScheduleMath.duration(of: kind, timing: timing))
        if virtualGap >= needed {
            resetCycle(afterCompleted: kind)
            setPhase(.working)
            emit(.breakEnded(kind: kind, reason: .autoIdle, elapsedSeconds: min(virtualGap, needed)))
            Log.engine.info("absence of \(Int(gap))s counted as \(kind.title, privacy: .public)")
        } else {
            setPhase(timeUntilBreak <= Double(timing.leadTimeSeconds) ? .preBreak : .working)
        }
    }

    func setHold(_ reason: HoldReason, active: Bool) {
        let before = holdReasons
        if active { holdReasons.insert(reason) } else { holdReasons.remove(reason) }
        guard holdReasons != before else { return }
        Log.engine.debug("hold reasons: \(self.holdReasons.map(\.rawValue).joined(separator: ","))")
    }

    // MARK: Debug helpers

    func debugSetTimeUntilBreak(_ seconds: Double) {
        workAccrued = Double(timing.workSeconds) - seconds
        if phase.isInactive || phase == .inBreak { return }
        // Respect holds like the real flow: no heads-up while something holds.
        let inLead = seconds <= Double(timing.leadTimeSeconds)
        setPhase(inLead && holdReasons.isEmpty ? .preBreak : .working)
    }

    var debugDescription: String {
        """
        phase=\(phase) workAccrued=\(Int(workAccrued))/\(timing.workSeconds) \
        untilBreak=\(Int(timeUntilBreak)) next=\(nextBreakKind.title) \
        shortsSinceLong=\(shortBreaksSinceLong) snoozes=\(snoozesThisCycle) \
        holds=[\(holdReasons.map(\.rawValue).joined(separator: ","))]
        """
    }
}
