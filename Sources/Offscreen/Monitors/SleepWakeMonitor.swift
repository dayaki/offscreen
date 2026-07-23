import AppKit

/// Reports system sleep / display sleep / screen lock / fast-user-switch as a
/// single "suspended" signal, and the real-seconds gap on resume. Wall clock
/// is used for the gap: it keeps counting however deep the sleep was.
final class SleepWakeMonitor {
    private var suspendedAt: Date?
    private var tokens: [NSObjectProtocol] = []
    private let onSuspend: () -> Void
    private let onResume: (TimeInterval) -> Void

    init(onSuspend: @escaping () -> Void, onResume: @escaping (TimeInterval) -> Void) {
        self.onSuspend = onSuspend
        self.onResume = onResume

        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification, suspend)
        observe(workspace, NSWorkspace.screensDidSleepNotification, suspend)
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification, suspend)
        observe(workspace, NSWorkspace.didWakeNotification, resume)
        observe(workspace, NSWorkspace.screensDidWakeNotification, resume)
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification, resume)

        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked"), suspend)
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked"), resume)
        observe(distributed, Notification.Name("com.apple.screensaver.didstart"), suspend)
        observe(distributed, Notification.Name("com.apple.screensaver.didstop"), resume)
    }

    private func observe(
        _ center: NotificationCenter,
        _ name: Notification.Name,
        _ action: @escaping @MainActor () -> Void
    ) {
        tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { action() }
        })
    }

    private func suspend() {
        guard suspendedAt == nil else { return }
        suspendedAt = Date()
        Log.monitors.info("suspended (sleep/lock)")
        onSuspend()
    }

    private func resume() {
        guard let start = suspendedAt else { return }
        suspendedAt = nil
        let gap = Date().timeIntervalSince(start)
        Log.monitors.info("resumed after \(Int(gap))s away")
        onResume(gap)
    }
}
