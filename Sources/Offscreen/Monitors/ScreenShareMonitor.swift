import CoreGraphics
import Foundation

/// Best-effort detection of the screen being captured or observed. There is
/// no public API for this; `CGSIsScreenWatcherPresent` (SkyLight, private but
/// long-stable) is resolved at runtime and skipped gracefully if it ever
/// disappears. Requires two consecutive positive polls so a user screenshot
/// doesn't count.
final class ScreenShareMonitor {
    private(set) var isShared = false
    private var timer: Timer?
    private var positiveStreak = 0
    private let onChange: (Bool) -> Void

    private typealias WatcherFn = @convention(c) () -> Bool
    private let watcherPresent: WatcherFn?

    init(onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        if let symbol = dlsym(dlopen(nil, RTLD_NOW), "CGSIsScreenWatcherPresent") {
            watcherPresent = unsafeBitCast(symbol, to: WatcherFn.self)
        } else {
            watcherPresent = nil
            Log.monitors.info("CGSIsScreenWatcherPresent unavailable; screen-share detection limited")
        }
        timer = Poll.every(2.0) { [weak self] in self?.poll() }
    }

    private func poll() {
        let captured = watcherPresent?() ?? false
        let remoteShared = (CGSessionCopyCurrentDictionary() as? [String: Any])?[
            "CGSSessionScreenIsShared"
        ] as? Bool ?? false

        positiveStreak = (captured || remoteShared) ? positiveStreak + 1 : 0
        let next = positiveStreak >= 2
        guard next != isShared else { return }
        isShared = next
        Log.monitors.info("screen shared/captured: \(next)")
        onChange(next)
    }
}
