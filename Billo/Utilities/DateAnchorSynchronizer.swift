//  Created by Jiri Urbasek on 01/26/26.

import Foundation

/// Handles synchronization between anchor dates and recurrence fields (weekday, day of month).
/// Extracted from RecurrencePresetPicker for testability.
struct DateAnchorSynchronizer {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    // MARK: - Extract from Date

    /// Extracts the weekday from a date.
    func weekday(from date: Date) -> Weekday {
        let weekdayValue = calendar.component(.weekday, from: date)
        return Weekday.fromCalendarWeekday(weekdayValue) ?? .monday
    }

    /// Extracts the day of month from a date.
    func dayOfMonth(from date: Date) -> Int {
        calendar.component(.day, from: date)
    }

    // MARK: - Sync Date to Field

    /// Snaps the anchor date forward to match the target weekday.
    /// Returns nil if no change is needed.
    func syncDateToWeekday(_ date: Date, weekday: Weekday) -> Date? {
        let snappedDate = RecurrenceRuleGenerator.snapToWeekday(
            date,
            weekday: weekday,
            calendar: calendar
        )

        return snappedDate != date ? snappedDate : nil
    }

    /// Snaps the anchor date to match the target day of month.
    /// If the target day is before the current day, moves to the next month.
    /// Returns nil if no change is needed.
    func syncDateToDayOfMonth(_ date: Date, targetDay: Int) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        let currentDay = components.day ?? 1

        guard currentDay != targetDay else { return nil }

        // Get days in current month
        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 31
        let adjustedDay = min(targetDay, daysInMonth)

        components.day = adjustedDay

        guard let newDate = calendar.date(from: components) else { return nil }

        // If the new date is before the current date, move to next month
        if newDate < date {
            return nextMonthDate(for: targetDay, after: newDate)
        } else {
            return newDate
        }
    }

    // MARK: - Private Helpers

    private func nextMonthDate(for targetDay: Int, after date: Date) -> Date? {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) else {
            return nil
        }

        let daysInNextMonth = calendar.range(of: .day, in: .month, for: nextMonth)?.count ?? 31
        var nextComponents = calendar.dateComponents([.year, .month], from: nextMonth)
        nextComponents.day = min(targetDay, daysInNextMonth)

        return calendar.date(from: nextComponents)
    }
}
