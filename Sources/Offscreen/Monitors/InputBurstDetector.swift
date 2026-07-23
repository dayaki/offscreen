import CoreGraphics
import Foundation

/// Briefly defers an imminent break while the user is mid-keystroke or
/// mid-drag, using permission-free CGEventSource queries (never a tap or
/// monitor). The defer is capped so typing can't postpone a break forever.
final class InputBurstDetector {
    private let engine: BreakEngine
    private var config: () -> SmartPauseConfig
    private var timer: Timer?
    private var deferStartedAt: ContinuousClock.Instant?
    private let clock = ContinuousClock()

    init(engine: BreakEngine, config: @escaping () -> SmartPauseConfig) {
        self.engine = engine
        self.config = config
        timer = Poll.every(0.5) { [weak self] in self?.poll() }
    }

    private func poll() {
        let cfg = config()
        // Only relevant in the moments a break is about to fire.
        let imminent = (engine.phase == .preBreak && engine.timeUntilBreak <= 2)
            || engine.phase == .holding
        guard imminent, cfg.deferWhileTypingSeconds > 0 else {
            deferStartedAt = nil
            engine.setHold(.typing, active: false)
            return
        }

        let typing = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState, eventType: .keyDown
        ) < Double(cfg.deferWhileTypingSeconds)
        let dragging = CGEventSource.buttonState(.combinedSessionState, button: .left)
        var active = typing || dragging

        if active {
            let started = deferStartedAt ?? clock.now
            deferStartedAt = started
            if started.duration(to: clock.now).seconds > Double(cfg.maxTypingDeferSeconds) {
                active = false // cap reached — let the break through
            }
        } else {
            deferStartedAt = nil
        }
        engine.setHold(.typing, active: active)
    }
}
