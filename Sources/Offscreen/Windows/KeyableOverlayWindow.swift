import AppKit

/// Borderless windows refuse key status by default, which would leave the
/// overlay's buttons and Esc handling dead — so allow it explicitly.
final class KeyableOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
