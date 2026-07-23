import Foundation

/// Motivational prompts shown on the break overlay, picked per break.
enum BreakMessages {
    static let short = [
        "Look at something far away",
        "Rest your eyes on the horizon",
        "Blink slowly a few times",
        "Gaze out the window",
        "Unclench your jaw, drop your shoulders",
        "Take a slow, deep breath",
        "Roll your shoulders back",
        "Soften your gaze",
    ]

    static let long = [
        "Step away from your desk",
        "Go grab a glass of water",
        "Take a short walk",
        "Stretch your back and legs",
        "Get some fresh air if you can",
        "Stand up and move around",
    ]

    /// Custom lists (from settings) win when non-empty.
    static func random(for kind: BreakKind, customShort: [String] = [], customLong: [String] = []) -> String {
        switch kind {
        case .short:
            let pool = customShort.isEmpty ? short : customShort
            return pool.randomElement() ?? "Look at something far away"
        case .long, .planned:
            let pool = customLong.isEmpty ? long : customLong
            return pool.randomElement() ?? "Step away from your desk"
        }
    }
}
