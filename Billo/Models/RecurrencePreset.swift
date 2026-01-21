//  Created by Jiri Urbasek on 1/20/26.

import Foundation

enum RecurrencePreset: String, CaseIterable, Identifiable, Codable {
    case none
    case weekly
    case biweekly
    case monthly
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:
            return String(localized: "Never", comment: "Repeat menu option: does not repeat")
        case .weekly:
            return String(localized: "Every Week", comment: "Repeat menu option: repeats every week")
        case .biweekly:
            return String(localized: "Every 2 Weeks", comment: "Repeat menu option: repeats every 2 weeks")
        case .monthly:
            return String(localized: "Every Month", comment: "Repeat menu option: repeats every month")
        case .custom:
            return String(localized: "Custom", comment: "Repeat menu option: shows advanced recurrence configuration")
        }
    }
}

extension RecurrencePreset {
    @MainActor
    func buildRecurrenceRule(
        intervalType: RepeatIntervalType,
        frequency: Int,
        dayOfWeek: Weekday,
        dayOfMonth: Int,
        endConditionType: EndConditionType = .never,
        endDate: Date? = nil
    ) -> RecurrenceRule? {
        switch self {
        case .none:
            return nil

        case .weekly:
            return RecurrenceRule(
                pattern: .weekly,
                frequency: 1,
                dayOfWeek: dayOfWeek,
                dayOfMonth: nil,
                endConditionType: endConditionType,
                endDate: endConditionType == .endDate ? endDate : nil
            )

        case .biweekly:
            return RecurrenceRule(
                pattern: .weekly,
                frequency: 2,
                dayOfWeek: dayOfWeek,
                dayOfMonth: nil,
                endConditionType: endConditionType,
                endDate: endConditionType == .endDate ? endDate : nil
            )

        case .monthly:
            return RecurrenceRule(
                pattern: .monthly,
                frequency: 1,
                dayOfWeek: nil,
                dayOfMonth: dayOfMonth,
                endConditionType: endConditionType,
                endDate: endConditionType == .endDate ? endDate : nil
            )

        case .custom:
            return RecurrenceRule(
                pattern: intervalType,
                frequency: frequency,
                dayOfWeek: intervalType == .weekly ? dayOfWeek : nil,
                dayOfMonth: intervalType == .monthly ? dayOfMonth : nil,
                endConditionType: endConditionType,
                endDate: endConditionType == .endDate ? endDate : nil
            )
        }
    }
}
