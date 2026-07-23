import AppKit
import SwiftUI

/// Slide-in heads-up panel shown during the pre-break lead window. The panel
/// never activates the app or steals key status, so the user can keep typing —
/// and it joins fullscreen Spaces where system notifications wouldn't appear.
final class PreBreakPanelController {
    private let engine: BreakEngine
    private var panel: NSPanel?
    private var hosting: NSHostingView<PreBreakView>?
    /// Where the user last dragged the panel, kept for the session so it
    /// reappears where they left it instead of snapping back over their work.
    private var userOrigin: NSPoint?

    private static let size = NSSize(width: 385, height: 130)
    private static let margin: CGFloat = 16

    init(engine: BreakEngine) {
        self.engine = engine
        engine.addListener { [weak self] event in
            guard case .phaseChanged(let old, let new) = event else { return }
            if new == .preBreak {
                self?.show()
            } else if old == .preBreak {
                self?.hide()
            }
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = true // user can drag it out of the way
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        let hosting = NSHostingView(
            rootView: PreBreakView(engine: engine, line: PreBreakCopy.line(for: engine.nextBreakKind))
        )
        panel.contentView = hosting
        self.hosting = hosting
        return panel
    }

    private func targetOrigin(on screen: NSScreen, panelSize: NSSize) -> NSPoint {
        let defaultOrigin = NSPoint(
            x: screen.visibleFrame.maxX - panelSize.width - Self.margin,
            y: screen.visibleFrame.maxY - panelSize.height - Self.margin
        )
        // Reuse the user's dragged spot if it's still on a connected display.
        guard let userOrigin else { return defaultOrigin }
        let rect = NSRect(origin: userOrigin, size: panelSize)
        let onScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(rect) }
        return onScreen ? userOrigin : defaultOrigin
    }

    func show() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let panel = self.panel ?? makePanel()
        self.panel = panel

        // Fresh playful line on every appearance; the card sizes itself, so
        // keep the panel frame in sync for the top-right anchoring math.
        hosting?.rootView = PreBreakView(engine: engine, line: PreBreakCopy.line(for: engine.nextBreakKind))
        if let hosting { panel.setContentSize(hosting.fittingSize) }

        let origin = targetOrigin(on: screen, panelSize: panel.frame.size)
        // Slide in from just above the visible frame while fading.
        panel.setFrameOrigin(NSPoint(x: origin.x, y: origin.y + 24))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrameOrigin(origin)
        }
        Log.windows.info("pre-break panel shown")
    }

    func hide() {
        guard let panel else { return }
        // Remember where it ended up so the next heads-up reappears there.
        userOrigin = panel.frame.origin
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { panel.orderOut(nil) }
        }
    }
}
