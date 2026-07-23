import SwiftUI
import AppKit

/// Offscreen's universal palette — the website's "golden hour" scheme
/// (site/index.html custom properties), shared by the settings window, the
/// stats window, the heads-up card, and the break overlay.
enum Theme {
    // MARK: Adaptive accents (windows that follow system appearance)

    /// #ffb45c on dark surfaces, #e08b1f in light mode.
    static let amber = Color(light: 0xE08B1F, dark: 0xFFB45C)
    /// #ff7d9c on dark surfaces, #e0447a in light mode.
    static let rose = Color(light: 0xE0447A, dark: 0xFF7D9C)
    /// #b78cff on dark surfaces, #7a4fd6 in light mode.
    static let violet = Color(light: 0x7A4FD6, dark: 0xB78CFF)
    /// Blend of rose and violet, for a fourth distinct tint.
    static let plum = Color(light: 0xB04AA8, dark: 0xDB84CD)

    /// The site's hero gradient: amber → rose → violet.
    static let brandGradient = LinearGradient(
        colors: [Color(hex: 0xFFB45C), Color(hex: 0xFF7D9C), Color(hex: 0xB78CFF)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // MARK: Fixed dusk tones (always-dark surfaces: overlay, heads-up card)

    enum Dusk {
        static let bg0 = Color(hex: 0x0A0612)
        static let bg1 = Color(hex: 0x140C20)
        static let cardTop = Color(hex: 0x2A1A40)
        static let cardBottom = Color(hex: 0x160D26)
        static let amber = Color(hex: 0xFFB45C)
        static let rose = Color(hex: 0xFF7D9C)
        static let violet = Color(hex: 0xB78CFF)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// Dynamic color that resolves per system appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
