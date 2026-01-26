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
    @MainActor
    func generateOccurrences(
        from startDate: Date,
        until maxDate: Date,
        calendar: Calendar
    ) -> [Date] {
        RecurrenceRuleGenerator.generateOccurrences(
            pattern: pattern,
            frequency: frequency,
            dayOfWeek: dayOfWeek,
            dayOfMonth: dayOfMonth,
            endConditionType: endConditionType,
            endDate: endDate,
            from: startDate,
            until: maxDate,
            calendar: calendar
        )
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
