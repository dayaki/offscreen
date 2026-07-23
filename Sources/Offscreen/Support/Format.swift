import Foundation

enum Format {
    /// "19:32" for durations under an hour, "1:04:09" above.
    static func clock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    /// "20 min", "20 sec", "1 hr 30 min" — for settings labels.
    static func duration(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) sec" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) hr") }
        if m > 0 { parts.append("\(m) min") }
        if s > 0 { parts.append("\(s) sec") }
        return parts.joined(separator: " ")
    }
}
