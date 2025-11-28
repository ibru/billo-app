//  Created by Jiri Urbasek on 11/26/25.

import SwiftData
import Foundation

@Model
final class RecurrenceRule {
    var pattern: RepeatIntervalType
    var frequency: Int
    var dayOfWeek: Weekday?
    var dayOfMonth: Int?
    var endConditionType: EndConditionType
    var endDate: Date?

    init(
        pattern: RepeatIntervalType,
        frequency: Int = 1,
        dayOfWeek: Weekday? = nil,
        dayOfMonth: Int? = nil,
        endConditionType: EndConditionType = .never,
        endDate: Date? = nil
    ) {
        self.pattern = pattern
        self.frequency = frequency
        self.dayOfWeek = dayOfWeek
        self.dayOfMonth = dayOfMonth
        self.endConditionType = endConditionType
        self.endDate = endDate
    }
}

// MARK: - Occurrence Generation

extension RecurrenceRule {
    func generateOccurrences(
        from startDate: Date,
        until maxDate: Date,
        calendar: Calendar
    ) -> [Date] {
        var occurrences: [Date] = []
        var currentDate = startDate

        let effectiveEndDate: Date
        if endConditionType == .endDate, let end = endDate {
            effectiveEndDate = min(end, maxDate)
        } else {
            effectiveEndDate = maxDate
        }

        while currentDate <= effectiveEndDate {
            occurrences.append(currentDate)

            guard let nextDate = calculateNextOccurrence(after: currentDate, calendar: calendar) else {
                break
            }

            if nextDate > effectiveEndDate {
                break
            }

            currentDate = nextDate
        }

        return occurrences
    }

    private func calculateNextOccurrence(after date: Date, calendar: Calendar) -> Date? {
        switch pattern {
        case .daily:
            return calendar.date(byAdding: .day, value: frequency, to: date)

        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: frequency, to: date)

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

// MARK: - Supporting Types

enum RepeatIntervalType: String, Codable, CaseIterable {
    case daily
    case weekly
    case monthly
    case yearly
}

enum Weekday: Int, Codable, CaseIterable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    static func fromCalendarWeekday(_ weekday: Int) -> Weekday? {
        Weekday(rawValue: weekday)
    }

    var displayName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}

enum EndConditionType: String, Codable, CaseIterable {
    case never
    case endDate
}
