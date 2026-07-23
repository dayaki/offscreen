import AppKit
import SwiftUI

/// Shows the full-screen break overlay on every display. Windows sit at
/// screen-saver level and join all Spaces (including other apps' fullscreen
/// Spaces) without ever activating Offscreen itself.
final class OverlayWindowController {
    private let engine: BreakEngine
    private var windows: [NSWindow] = []
    private var keyMonitor: Any?
    private var screenObserver: NSObjectProtocol?

    /// Provided by the container so the overlay follows the appearance settings.
    var styleProvider: () -> OverlayStyle = { OverlayStyle() }

    var isVisible: Bool { !windows.isEmpty }

    init(engine: BreakEngine) {
        self.engine = engine
        engine.addListener { [weak self] event in
            switch event {
            case .breakStarted: self?.show()
            case .breakEnded: self?.hide()
            default: break
            }
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isVisible else { return }
                Log.windows.info("screens changed mid-break, rebuilding overlays")
                self.tearDown()
                self.show()
            }
        }
    }

    func show() {
        guard windows.isEmpty else { return }
        for screen in NSScreen.screens {
            let window = KeyableOverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.animationBehavior = .none
            window.contentView = NSHostingView(
                rootView: BreakOverlayView(engine: engine, style: styleProvider())
            )
            window.setFrame(screen.frame, display: true)
            window.alphaValue = 0
            window.orderFrontRegardless()
            windows.append(window)
        }
        // Only the primary display's overlay takes key status (skip button, Esc).
        windows.first?.makeKey()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            windows.forEach { $0.animator().alphaValue = 1 }
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc — same gating as the skip button
                if let engine = self?.engine, engine.canSkipOverlay {
                    engine.skipBreak()
                }
                return nil
            }
            return event
        }
        Log.windows.info("overlay shown on \(NSScreen.screens.count) screen(s)")
    }

    func hide() {
        guard !windows.isEmpty else { return }
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        let fading = windows
        windows = []
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            fading.forEach { $0.animator().alphaValue = 0 }
        } completionHandler: {
            // NSAnimationContext completion handlers run on the main thread.
            MainActor.assumeIsolated {
                fading.forEach { $0.orderOut(nil) }
            }
        }
    }

    private func tearDown() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        windows.forEach { $0.orderOut(nil) }
        windows = []
    }
}
