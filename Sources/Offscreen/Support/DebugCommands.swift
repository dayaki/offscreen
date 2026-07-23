import Foundation

/// CLI-driveable debug hooks via distributed notifications, e.g.:
///   swift -e 'import Foundation; DistributedNotificationCenter.default()
///     .postNotificationName(.init("com.dayo.offscreen.debug.breakNow"),
///     object: nil, userInfo: nil, deliverImmediately: true)'
final class DebugCommands {
    private var tokens: [NSObjectProtocol] = []

    init(engine: BreakEngine) {
        observe("com.dayo.offscreen.debug.breakNow") { engine.startBreakNow() }
        observe("com.dayo.offscreen.debug.skip") { engine.skipBreak() }
        observe("com.dayo.offscreen.debug.snooze") { engine.snooze(seconds: 60) }
        observe("com.dayo.offscreen.debug.preBreak") {
            engine.debugSetTimeUntilBreak(Double(engine.timing.leadTimeSeconds) - 1)
        }
        observe("com.dayo.offscreen.debug.dueNow") {
            engine.debugSetTimeUntilBreak(1)
        }
        observe("com.dayo.offscreen.debug.dump") {
            Log.engine.info("STATE: \(engine.debugDescription, privacy: .public)")
        }
    }

    private func observe(_ name: String, _ action: @escaping @MainActor () -> Void) {
        let token = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(name), object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { action() }
        }
        tokens.append(token)
    }
}
