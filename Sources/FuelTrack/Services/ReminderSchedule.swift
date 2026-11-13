import Foundation

/// Date maths for MOT, tax, insurance, and mileage reminders.
/// Kept free of UserNotifications so it can be checked without a device.
enum ReminderSchedule {
    /// 9:00 local, this many days before the due date. `0` is the morning of the due day.
    static let leadDays = [4, 3, 1, 0]

    static func leadLabel(daysBefore: Int) -> String {
        switch daysBefore {
        case 0: "today"
        case 1: "1 day"
        default: "\(daysBefore) days"
        }
    }

    /// 9:00 local on the calendar day that is `daysBefore` the due date.
    /// Returns nil when that morning is already past.
    static func notificationDate(daysBefore: Int, dueDate: Date, now: Date = .now, calendar: Calendar = .current) -> Date? {
        let dueDay = calendar.startOfDay(for: dueDate)
        guard let fireDay = calendar.date(byAdding: .day, value: -daysBefore, to: dueDay) else { return nil }
        var parts = calendar.dateComponents([.year, .month, .day], from: fireDay)
        parts.hour = 9
        parts.minute = 0
        guard let fire = calendar.date(from: parts), fire > now else { return nil }
        return fire
    }

    /// Mornings that are still ahead. Empty when every lead time has passed.
    static func upcomingNotifications(dueDate: Date, now: Date = .now, calendar: Calendar = .current) -> [Date] {
        leadDays.compactMap { notificationDate(daysBefore: $0, dueDate: dueDate, now: now, calendar: calendar) }
    }

    /// When the app is opened after the 9:00 slots have passed, but the due day
    /// is still today, fire one hour from now so the reminder is not lost.
    static func catchUpDate(dueDate: Date, now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard upcomingNotifications(dueDate: dueDate, now: now, calendar: calendar).isEmpty else { return nil }
        let dueDay = calendar.startOfDay(for: dueDate)
        let today = calendar.startOfDay(for: now)
        guard dueDay == today else { return nil }
        guard let soon = calendar.date(byAdding: .hour, value: 1, to: now), soon > now else { return nil }
        guard calendar.startOfDay(for: soon) == today else { return nil }
        return soon
    }

    /// Estimate when a mileage reminder comes due from the gap between two odometer readings.
    /// Fires at 9:00 the day before that estimate, or on the morning itself if that is the only slot left.
    static func odometerFireDate(
        dueOdometer: Double,
        latestOdometer: Double,
        latestDate: Date,
        earlierOdometer: Double,
        earlierDate: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date? {
        guard dueOdometer > latestOdometer else { return nil }
        let distance = latestOdometer - earlierOdometer
        let elapsed = latestDate.timeIntervalSince(earlierDate)
        guard distance > 1, elapsed > 0 else { return nil }
        let secondsRemaining = (dueOdometer - latestOdometer) / distance * elapsed
        let estimate = latestDate.addingTimeInterval(secondsRemaining)
        if let dayBefore = notificationDate(daysBefore: 1, dueDate: estimate, now: now, calendar: calendar) {
            return dayBefore
        }
        if let morning = notificationDate(daysBefore: 0, dueDate: estimate, now: now, calendar: calendar) {
            return morning
        }
        return catchUpDate(dueDate: estimate, now: now, calendar: calendar)
    }
}
