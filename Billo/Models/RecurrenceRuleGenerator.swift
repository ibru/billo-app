//  Created by Jiri Urbasek on 01/26/26.

import Foundation

struct RecurrenceRuleGenerator {
    /// Generates recurrence dates in a half-open range: `[from, until)`.
    /// - Important: `until` is exclusive.
    /// - Important: `endDate` remains user-inclusive and is converted internally.
    static func generateOccurrences(
        pattern: RepeatIntervalType,
        frequency: Int,
        dayOfWeek: Weekday?,
        dayOfMonth: Int?,
        endConditionType: EndConditionType,
        endDate: Date?,
        from startDate: Date,
        until maxDate: Date,
        calendar: Calendar
    ) -> [Date] {
        var occurrences: [Date] = []

        // For weekly patterns with explicit dayOfWeek, snap to the target weekday
        var currentDate = startDate
        if pattern == .weekly, let targetWeekday = dayOfWeek {
            currentDate = snapToWeekday(startDate, weekday: targetWeekday, calendar: calendar)
        }

        let effectiveEndDate: Date
        if endConditionType == .endDate, let endDate {
            // endDate is inclusive (user's "end on" date); convert to exclusive
            // so occurrences on the endDate are still included.
            let exclusiveEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? maxDate
            effectiveEndDate = min(exclusiveEnd, maxDate)
        } else {
            effectiveEndDate = maxDate
        }

        while currentDate < effectiveEndDate {
            occurrences.append(currentDate)

            guard let nextDate = calculateNextOccurrence(
                pattern: pattern,
                frequency: frequency,
                dayOfWeek: dayOfWeek,
                dayOfMonth: dayOfMonth,
                after: currentDate,
                calendar: calendar
            ) else {
                break
            }

            if nextDate >= effectiveEndDate {
                break
            }

            currentDate = nextDate
        }

        return occurrences
    }

    /// Snaps a date forward to the next occurrence of the target weekday.
    /// If the date is already on the target weekday, returns it unchanged.
    static func snapToWeekday(
        _ date: Date,
        weekday: Weekday,
        calendar: Calendar
    ) -> Date {
        let currentWeekday = calendar.component(.weekday, from: date)
        var daysToAdd = weekday.rawValue - currentWeekday
        if daysToAdd < 0 {
            daysToAdd += 7
        }
        // daysToAdd is 0 if already on target day, otherwise 1-6
        return calendar.date(byAdding: .day, value: daysToAdd, to: date) ?? date
    }

    private static func calculateNextOccurrence(
        pattern: RepeatIntervalType,
        frequency: Int,
        dayOfWeek: Weekday?,
        dayOfMonth: Int?,
        after date: Date,
        calendar: Calendar
    ) -> Date? {
        switch pattern {
        case .weekly:
            // Add frequency weeks (7 * frequency days)
            return calendar.date(byAdding: .day, value: 7 * frequency, to: date)

        case .monthly:
            guard let targetDay = dayOfMonth else {
                return calendar.date(byAdding: .month, value: frequency, to: date)
            }

            guard let nextMonth = calendar.date(byAdding: .month, value: frequency, to: date) else {
                return nil
            }

            let daysInNextMonth = calendar.range(of: .day, in: .month, for: nextMonth)?.count ?? 31
            let adjustedDay = min(targetDay, daysInNextMonth)

            var components = calendar.dateComponents([.year, .month], from: nextMonth)
            components.day = adjustedDay

            return calendar.date(from: components)

        case .yearly:
            return calendar.date(byAdding: .year, value: frequency, to: date)
        }
    }
}
