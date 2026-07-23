import AppKit

/// Attributes active screen time to the frontmost app in 5-second slices,
/// skipping idle periods, and flushes to SQLite once a minute.
final class ActivityTracker {
    private let stats: StatsStore
    var enabled: Bool

    private var timer: Timer?
    private var pending: [String: (name: String, seconds: Int)] = [:]
    private var ticksSinceFlush = 0

    private static let sliceSeconds = 5
    private static let idleCutoff: Double = 60

    init(stats: StatsStore, enabled: Bool) {
        self.stats = stats
        self.enabled = enabled
        timer = Poll.every(Double(Self.sliceSeconds)) { [weak self] in self?.tick() }
    }

    private func tick() {
        guard enabled else { return }
        defer {
            ticksSinceFlush += 1
            if ticksSinceFlush >= 12 { flush() }
        }
        guard IdleMonitor.idleSeconds() < Self.idleCutoff,
              let app = NSWorkspace.shared.frontmostApplication
        else { return }
        let bundleID = app.bundleIdentifier ?? app.localizedName ?? "unknown"
        pending[bundleID, default: (app.localizedName ?? bundleID, 0)].seconds += Self.sliceSeconds
    }

    func flush() {
        stats.addUsage(pending)
        pending = [:]
        ticksSinceFlush = 0
    }
}
