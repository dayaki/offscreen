import AppKit
import SwiftUI

final class StatsWindowController: NSObject {
    private let stats: StatsStore
    private var window: NSWindow?

    init(stats: StatsStore) {
        self.stats = stats
    }

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Offscreen Stats"
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: StatsView(stats: stats))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
