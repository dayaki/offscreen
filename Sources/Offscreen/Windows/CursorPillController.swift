import AppKit
import SwiftUI

/// Tiny click-through countdown pill that follows the cursor in the final
/// seconds before a break, so the break never catches the user off guard.
final class CursorPillController {
    private let engine: BreakEngine
    private var panel: NSPanel?
    private var moveTimer: Timer?

    private static let size = NSSize(width: 116, height: 34)

    init(engine: BreakEngine) {
        self.engine = engine
        engine.addListener { [weak self] event in
            switch event {
            case .tick, .phaseChanged: self?.sync()
            default: break
            }
        }
    }

    private func sync() {
        let shouldShow = engine.phase == .preBreak
            && engine.timeUntilBreak <= Double(engine.behavior.cursorPillSeconds)
            && engine.behavior.cursorPillSeconds > 0
        if shouldShow, panel == nil {
            show()
        } else if !shouldShow, panel != nil {
            hide()
        }
    }

    private func show() {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.contentView = NSHostingView(rootView: CursorPillView(engine: engine))
        self.panel = panel

        reposition()
        panel.orderFrontRegardless()

        // NSEvent.mouseLocation is a permission-free global read; 30 Hz only
        // while the pill is visible.
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
        RunLoop.main.add(timer, forMode: .common)
        moveTimer = timer
    }

    private func reposition() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let screen else { return }

        var origin = NSPoint(x: mouse.x + 18, y: mouse.y - Self.size.height - 14)
        origin.x = min(max(origin.x, screen.frame.minX), screen.frame.maxX - Self.size.width)
        origin.y = min(max(origin.y, screen.frame.minY), screen.frame.maxY - Self.size.height)
        panel.setFrameOrigin(origin)
    }

    private func hide() {
        moveTimer?.invalidate()
        moveTimer = nil
        panel?.orderOut(nil)
        panel = nil
    }
}

struct CursorPillView: View {
    let engine: BreakEngine

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "eyes")
                .font(.system(size: 11, weight: .semibold))
            Text(Format.clock(max(0, engine.timeUntilBreak)))
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.primary.opacity(0.15), lineWidth: 1))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
