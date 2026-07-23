import AppKit

/// Arms a wall-clock timer for the next enabled planned break and hands it to
/// the engine one lead-time early (so the normal pre-break panel, snoozes,
/// and Smart Pause holds all apply). Re-arms on wake, clock changes, config
/// edits, and after each firing.
final class PlannedBreakScheduler {
    private let engine: BreakEngine
    private var breaks: [PlannedBreak]
    private var timer: Timer?
    private var tokens: [NSObjectProtocol] = []

    init(engine: BreakEngine, breaks: [PlannedBreak]) {
        self.engine = engine
        self.breaks = breaks

        let observe: (NotificationCenter, Notification.Name) -> Void = { [weak self] center, name in
            let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { self?.rearm() }
            }
            self?.tokens.append(token)
        }
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification)
        observe(NotificationCenter.default, .NSSystemClockDidChange)
        rearm()
    }

    func configChanged(_ newBreaks: [PlannedBreak]) {
        breaks = newBreaks
        rearm()
    }

    private func rearm(after: Date = Date()) {
        timer?.invalidate()
        timer = nil
        guard let (plannedBreak, startDate) = nextOccurrence(after: after) else { return }

        // The countdown begins one lead-time before the scheduled moment
        // (lead is virtual seconds; convert to real for wall-clock math).
        let leadReal = Double(engine.timing.leadTimeSeconds) / engine.clock.timeScale
        let triggerDate = max(startDate.addingTimeInterval(-leadReal), Date().addingTimeInterval(1))

        let t = Timer(fire: triggerDate, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Log.engine.info("planned break due: \(plannedBreak.name, privacy: .public)")
                self.engine.startPlannedBreakCountdown(
                    .planned(name: plannedBreak.name, durationSeconds: plannedBreak.durationSeconds)
                )
                // Re-arm strictly past this occurrence, or the same one would
                // be found again (it is still in the future during its lead
                // window) and re-fire in a tight loop.
                self.rearm(after: startDate)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        Log.engine.info("next planned break: \(plannedBreak.name, privacy: .public) at \(startDate.formatted(), privacy: .public)")
    }

    /// Earliest upcoming occurrence across all enabled planned breaks,
    /// looking up to 8 days out to honor weekday selections.
    func nextOccurrence(after date: Date, calendar: Calendar = .current) -> (PlannedBreak, Date)? {
        var best: (PlannedBreak, Date)?
        for plannedBreak in breaks where plannedBreak.enabled && !plannedBreak.weekdays.isEmpty {
            for dayOffset in 0...8 {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: date),
                      plannedBreak.weekdays.contains(calendar.component(.weekday, from: day)),
                      let candidate = calendar.date(
                          bySettingHour: plannedBreak.hour, minute: plannedBreak.minute,
                          second: 0, of: day
                      ),
                      candidate > date
                else { continue }
                if best == nil || candidate < best!.1 {
                    best = (plannedBreak, candidate)
                }
                break // earliest day for this break found
            }
        }
        return best
    }
}
