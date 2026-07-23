import Foundation

/// Monotonic time source for the engine. `ContinuousClock` keeps advancing
/// across system sleep, so wake gaps are measurable; `timeScale` lets demo
/// runs compress minutes into seconds (OFFSCREEN_TIME_SCALE=60).
struct EngineClock: Sendable {
    let timeScale: Double
    private let clock = ContinuousClock()

    init(timeScale: Double? = nil) {
        let env = ProcessInfo.processInfo.environment["OFFSCREEN_TIME_SCALE"].flatMap(Double.init)
        self.timeScale = timeScale ?? env ?? 1
    }

    var now: ContinuousClock.Instant { clock.now }
}

extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) * 1e-18
    }
}
