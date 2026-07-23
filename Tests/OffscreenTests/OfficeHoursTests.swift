import Testing
import Foundation
@testable import Offscreen

@Suite struct OfficeHoursTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// 2026-07-15 was a Wednesday (weekday 4).
    private func date(hour: Int, minute: Int = 0, day: Int = 15) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour, minute: minute))!
    }

    @Test func disabledMeansAlwaysWithin() {
        var config = OfficeHoursConfig()
        config.enabled = false
        #expect(OfficeHours.isWithin(config, date: date(hour: 3), calendar: calendar))
    }

    @Test func simpleWindow() {
        var config = OfficeHoursConfig(enabled: true) // 9:00–18:00, Mon–Fri
        config.startMinute = 9 * 60
        config.endMinute = 18 * 60
        #expect(OfficeHours.isWithin(config, date: date(hour: 9), calendar: calendar))
        #expect(OfficeHours.isWithin(config, date: date(hour: 17, minute: 59), calendar: calendar))
        #expect(!OfficeHours.isWithin(config, date: date(hour: 18), calendar: calendar))
        #expect(!OfficeHours.isWithin(config, date: date(hour: 8, minute: 59), calendar: calendar))
    }

    @Test func weekdayExclusion() {
        var config = OfficeHoursConfig(enabled: true)
        config.weekdays = [2, 3, 4, 5, 6] // Mon–Fri
        // 2026-07-18 was a Saturday (weekday 7).
        #expect(!OfficeHours.isWithin(config, date: date(hour: 12, day: 18), calendar: calendar))
        #expect(OfficeHours.isWithin(config, date: date(hour: 12, day: 15), calendar: calendar))
    }

    @Test func midnightCrossingWindow() {
        var config = OfficeHoursConfig(enabled: true) // 22:00–06:00
        config.startMinute = 22 * 60
        config.endMinute = 6 * 60
        config.weekdays = [1, 2, 3, 4, 5, 6, 7]
        #expect(OfficeHours.isWithin(config, date: date(hour: 23), calendar: calendar))
        #expect(OfficeHours.isWithin(config, date: date(hour: 5, minute: 59), calendar: calendar))
        #expect(!OfficeHours.isWithin(config, date: date(hour: 6), calendar: calendar))
        #expect(!OfficeHours.isWithin(config, date: date(hour: 12), calendar: calendar))
    }
}

@Suite struct PlannedBreakSchedulerTests {
    @Test func nextOccurrenceSkipsDisabledAndWrongWeekdays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        // Wednesday 2026-07-15 10:00 UTC
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 10))!

        var lunch = PlannedBreak()
        lunch.name = "Lunch"
        lunch.hour = 12; lunch.minute = 30
        var walk = PlannedBreak()
        walk.name = "Walk"
        walk.hour = 9; walk.minute = 0 // already past today → next matching day
        var disabled = PlannedBreak()
        disabled.hour = 11; disabled.enabled = false

        let engine = BreakEngine(timing: .balanced, clock: EngineClock(timeScale: 1))
        let scheduler = PlannedBreakScheduler(engine: engine, breaks: [])
        scheduler.configChanged([lunch, walk, disabled])

        let next = scheduler.nextOccurrence(after: now, calendar: calendar)
        #expect(next?.0.name == "Lunch")
        let expected = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12, minute: 30))!
        #expect(next?.1 == expected)
    }
}
