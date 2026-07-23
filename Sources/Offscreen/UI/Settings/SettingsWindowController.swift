import AppKit
import SwiftUI

final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let store: SettingsStore
    private let login: LoginItemManager
    private var window: NSWindow?

    init(store: SettingsStore, login: LoginItemManager) {
        self.store = store
        self.login = login
    }

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 780, height: 540),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Offscreen Settings"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(
                rootView: SettingsRootView(store: store, login: login)
            )
            window.setContentSize(NSSize(width: 780, height: 540))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
