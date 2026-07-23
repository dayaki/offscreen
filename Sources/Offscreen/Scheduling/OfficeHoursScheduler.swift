import AppKit

/// Flips the engine between active and outside-office-hours. Wall-clock
/// driven, so it re-evaluates on wake and clock changes as well as polling.
final class OfficeHoursScheduler {
    private let engine: BreakEngine
    private var config: OfficeHoursConfig {
        didSet { evaluate() }
    }
    private var timer: Timer?
    private var tokens: [NSObjectProtocol] = []

    init(engine: BreakEngine, config: OfficeHoursConfig) {
        self.engine = engine
        self.config = config

        timer = Poll.every(30) { [weak self] in self?.evaluate() }
        let observe: (NotificationCenter, Notification.Name) -> Void = { [weak self] center, name in
            let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { self?.evaluate() }
            }
            self?.tokens.append(token)
        }
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification)
        observe(NotificationCenter.default, .NSSystemClockDidChange)

        // Manual resume while outside hours should be re-flagged promptly.
        engine.addListener { [weak self] event in
            if case .phaseChanged(_, .working) = event { self?.evaluate() }
        }
        evaluate()
    }

    func configChanged(_ newConfig: OfficeHoursConfig) {
        config = newConfig
    }

    private func evaluate() {
        engine.setOfficeHoursActive(OfficeHours.isWithin(config, date: Date()))
    }
}
