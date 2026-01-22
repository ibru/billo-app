//  Created by Jiri Urbasek on 11/26/25.

import SwiftData
import Foundation

@Model
final class RecurrenceRule {
    var pattern: RepeatIntervalType = RepeatIntervalType.monthly
    var frequency: Int = 1
    var dayOfWeek: Weekday?
    var dayOfMonth: Int?
    var endConditionType: EndConditionType = EndConditionType.never
    var endDate: Date?

    // CloudKit requires all relationships to be optional with explicit inverses
    var bill: Bill?
    var income: Income?

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

// MARK: - Preset Detection

extension RecurrenceRule {
    var matchingPreset: RecurrencePreset {
        switch (pattern, frequency) {
        case (.weekly, 1) where dayOfWeek != nil:
            return .weekly
        case (.weekly, 2) where dayOfWeek != nil:
            return .biweekly
        case (.monthly, 1) where dayOfMonth != nil:
            return .monthly
        default:
            return .custom
        }
    }
}

// MARK: - Supporting Types

enum RepeatIntervalType: String, Codable, CaseIterable {
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"

    var displayName: String {
        switch self {
        case .weekly: return String(localized: "Weekly")
        case .monthly: return String(localized: "Monthly")
        case .yearly: return String(localized: "Yearly")
        }
    }
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

    func displayName(locale: Locale = .autoupdatingCurrent) -> String {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = locale
        return calendar.weekdaySymbols[rawValue - 1]
    }

    var displayName: String { displayName() }
}

enum EndConditionType: String, Codable, CaseIterable {
    case never = "never"
    case endDate = "endDate"
}
