import Foundation
import GRDB

struct DayStats: Identifiable, Equatable {
    var id: String { day }
    let day: String // "2026-07-18" (local)
    var activeSeconds = 0
    var completed = 0
    var skipped = 0
    var snoozes = 0

    var score: Int {
        ScreenScore.compute(
            activeSeconds: activeSeconds, completed: completed,
            skipped: skipped, snoozes: snoozes
        )
    }
}

/// SQLite-backed stats (GRDB). All calls are tiny synchronous writes/reads on
/// the main actor; the database lives next to settings in App Support.
final class StatsStore {
    private var dbQueue: DatabaseQueue?

    static let fileURL = SettingsStore.directoryURL.appendingPathComponent("stats.sqlite")

    /// Pass nil to run in-memory (tests).
    init(url: URL? = StatsStore.fileURL) {
        do {
            let queue: DatabaseQueue
            if let url {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true
                )
                queue = try DatabaseQueue(path: url.path)
            } else {
                queue = try DatabaseQueue()
            }
            try Self.migrate(queue)
            dbQueue = queue
        } catch {
            Log.stats.error("stats database unavailable: \(error, privacy: .public)")
            dbQueue = nil
        }
    }

    private static func migrate(_ queue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "break_event") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("at", .datetime).notNull()
                t.column("day", .text).notNull().indexed()
                t.column("kind", .text).notNull()
                t.column("action", .text).notNull() // completed|endedEarly|autoIdle|skipped|snoozed
                t.column("scheduledSecs", .integer).notNull()
                t.column("actualSecs", .integer).notNull()
            }
            try db.create(table: "app_usage") { t in
                t.column("day", .text).notNull()
                t.column("bundleId", .text).notNull()
                t.column("appName", .text).notNull()
                t.column("seconds", .integer).notNull()
                t.primaryKey(["day", "bundleId"])
            }
        }
        try migrator.migrate(queue)
    }

    static func dayString(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: Writes

    func recordBreak(kind: BreakKind, action: String, scheduledSecs: Int, actualSecs: Int) {
        let kindName: String
        switch kind {
        case .short: kindName = "short"
        case .long: kindName = "long"
        case .planned(let name, _): kindName = "planned:\(name)"
        }
        try? dbQueue?.write { db in
            try db.execute(
                sql: """
                INSERT INTO break_event (at, day, kind, action, scheduledSecs, actualSecs)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                arguments: [Date(), Self.dayString(), kindName, action, scheduledSecs, actualSecs]
            )
        }
    }

    func addUsage(_ pending: [String: (name: String, seconds: Int)], day: String = StatsStore.dayString()) {
        guard !pending.isEmpty else { return }
        try? dbQueue?.write { db in
            for (bundleID, entry) in pending {
                try db.execute(
                    sql: """
                    INSERT INTO app_usage (day, bundleId, appName, seconds)
                    VALUES (?, ?, ?, ?)
                    ON CONFLICT(day, bundleId)
                    DO UPDATE SET seconds = seconds + excluded.seconds, appName = excluded.appName
                    """,
                    arguments: [day, bundleID, entry.name, entry.seconds]
                )
            }
        }
    }

    // MARK: Reads

    func history(days: Int) -> [DayStats] {
        guard let dbQueue else { return [] }
        let calendar = Calendar.current
        let dayKeys: [String] = (0..<days).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: Date()).map(Self.dayString)
        }
        var byDay = [String: DayStats]()
        for key in dayKeys { byDay[key] = DayStats(day: key) }

        try? dbQueue.read { db in
            let usageRows = try Row.fetchAll(
                db,
                sql: "SELECT day, SUM(seconds) AS total FROM app_usage WHERE day >= ? GROUP BY day",
                arguments: [dayKeys.first ?? ""]
            )
            for row in usageRows {
                byDay[row["day"]]?.activeSeconds = row["total"] ?? 0
            }
            let eventRows = try Row.fetchAll(
                db,
                sql: "SELECT day, action, COUNT(*) AS n FROM break_event WHERE day >= ? GROUP BY day, action",
                arguments: [dayKeys.first ?? ""]
            )
            for row in eventRows {
                let n: Int = row["n"] ?? 0
                switch row["action"] as String? {
                case "completed", "endedEarly", "autoIdle":
                    byDay[row["day"]]?.completed += n
                case "skipped":
                    byDay[row["day"]]?.skipped += n
                case "snoozed":
                    byDay[row["day"]]?.snoozes += n
                default: break
                }
            }
        }
        return dayKeys.compactMap { byDay[$0] }
    }

    func topApps(day: String = StatsStore.dayString(), limit: Int = 6) -> [(name: String, seconds: Int)] {
        guard let dbQueue else { return [] }
        var result: [(String, Int)] = []
        try? dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT appName, seconds FROM app_usage WHERE day = ? ORDER BY seconds DESC LIMIT ?",
                arguments: [day, limit]
            )
            result = rows.map { ($0["appName"] ?? "?", $0["seconds"] ?? 0) }
        }
        return result
    }
}
