import AppKit

/// Reports when a user-designated "deep focus" app is frontmost.
final class FocusAppMonitor {
    var bundleIDs: Set<String> {
        didSet { evaluate() }
    }

    private(set) var isFocusAppActive = false
    private var observer: NSObjectProtocol?
    private let onChange: (Bool) -> Void

    init(bundleIDs: Set<String>, onChange: @escaping (Bool) -> Void) {
        self.bundleIDs = bundleIDs
        self.onChange = onChange
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { [weak self] in self?.evaluate() }
        }
        evaluate()
    }

    private func evaluate() {
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let active = frontmost.map { bundleIDs.contains($0) } ?? false
        guard active != isFocusAppActive else { return }
        isFocusAppActive = active
        Log.monitors.info("focus app frontmost: \(active)")
        onChange(active)
    }
}
