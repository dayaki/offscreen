import AppKit

/// Optional auto-lock when a break starts. Uses the private
/// `SACLockScreenImmediate` (same lock as Ctrl+Cmd+Q), resolved at runtime,
/// with the public `CGSession -suspend` binary as fallback.
final class ScreenLocker {
    private typealias LockFn = @convention(c) () -> Int32
    private let lockFn: LockFn?
    private let isEnabled: () -> Bool

    init(engine: BreakEngine, isEnabled: @escaping () -> Bool) {
        self.isEnabled = isEnabled
        if let handle = dlopen(
            "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_NOW
        ), let symbol = dlsym(handle, "SACLockScreenImmediate") {
            lockFn = unsafeBitCast(symbol, to: LockFn.self)
        } else {
            lockFn = nil
        }

        engine.addListener { [weak self] event in
            guard let self, case .breakStarted = event, self.isEnabled() else { return }
            self.lock()
        }
    }

    func lock() {
        if let lockFn {
            _ = lockFn()
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath:
            "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession")
        process.arguments = ["-suspend"]
        try? process.run()
    }
}
