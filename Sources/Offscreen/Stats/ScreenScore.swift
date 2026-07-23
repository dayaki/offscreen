import Foundation

/// Daily screen-health score, 0–100. Completed breaks are the baseline;
/// skips hurt most, snoozes a little, and taking no breaks at all during
/// long active time hurts too.
enum ScreenScore {
    static func compute(activeSeconds: Int, completed: Int, skipped: Int, snoozes: Int) -> Int {
        var score = 100
        score -= skipped * 8
        score -= snoozes * 2
        // Penalize break droughts: expect roughly one break per half hour
        // of active screen time.
        let expected = activeSeconds / 1800
        if expected > 0, completed < expected {
            score -= min(30, (expected - completed) * 3)
        }
        return max(0, min(100, score))
    }
}
