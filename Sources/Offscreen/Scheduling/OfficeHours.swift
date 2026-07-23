import Foundation

/// Pure office-hours math. A window whose end is before its start crosses
/// midnight (e.g. 22:00–06:00); the weekday check applies to the calendar
/// day of the moment being tested.
enum OfficeHours {
    static func isWithin(_ config: OfficeHoursConfig, date: Date, calendar: Calendar = .current) -> Bool {
        guard config.enabled else { return true }
        guard config.weekdays.contains(calendar.component(.weekday, from: date)) else { return false }
        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        if config.startMinute <= config.endMinute {
            return minutes >= config.startMinute && minutes < config.endMinute
        }
        return minutes >= config.startMinute || minutes < config.endMinute
    }
}
