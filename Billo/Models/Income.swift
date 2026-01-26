//  Created by Jiri Urbasek on 11/26/25.

import SwiftData
import Foundation

// MARK: - Validation Error

enum IncomeValidationError: Error, LocalizedError, Equatable {
    case emptyName
    case nonPositiveAmount
    case endDateBeforeStartDate

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return String(localized: "Income name cannot be empty")
        case .nonPositiveAmount:
            return String(localized: "Income amount must be greater than zero")
        case .endDateBeforeStartDate:
            return String(localized: "End date must be on or after start date")
        }
    }
}

// MARK: - Income Model

@Model
final class Income {
    var name: String = ""
    var amount: Decimal = 0
    var currencyCode: String = "USD"
    var startDate: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \RecurrenceRule.income)
    var recurrenceRule: RecurrenceRule?
    var createdDate: Date = Date()
    var lastUpdatedDate: Date = Date()

    init(
        name: String,
        amount: Decimal,
        currencyCode: String = Locale.current.currency?.identifier ?? "USD",
        startDate: Date,
        recurrenceRule: RecurrenceRule? = nil
    ) {
        self.name = name
        self.amount = amount
        self.currencyCode = currencyCode
        self.startDate = startDate
        self.recurrenceRule = recurrenceRule
        self.createdDate = Date()
        self.lastUpdatedDate = Date()
    }
}

// MARK: - Validated Factory

extension Income {
    /// Creates a validated Income. Throws IncomeValidationError if validation fails.
    /// Use this instead of direct init to ensure data integrity.
    /// Currency code should come from AppSettingsModel.currencyCode
    static func create(
        name: String,
        amount: Decimal,
        currencyCode: String,
        startDate: Date,
        recurrenceRule: RecurrenceRule? = nil
    ) throws -> Income {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            throw IncomeValidationError.emptyName
        }
        guard amount > 0 else {
            throw IncomeValidationError.nonPositiveAmount
        }
        if
            let recurrenceRule,
            recurrenceRule.endConditionType == .endDate,
            let endDate = recurrenceRule.endDate,
            endDate < startDate
        {
            throw IncomeValidationError.endDateBeforeStartDate
        }

        return Income(
            name: trimmedName,
            amount: amount,
            currencyCode: currencyCode,
            startDate: startDate,
            recurrenceRule: recurrenceRule
        )
    }
}

// MARK: - Occurrence Generation

extension Income {
    /// Generate income dates within a range, delegating to RecurrenceRule.
    /// CRITICAL: Always generates from startDate (anchor) then filters to window.
    /// This matches Bill.generateOccurrences behavior and prevents schedule drift.
    @MainActor
    func generateOccurrences(
        from rangeStart: Date,
        until rangeEnd: Date,
        calendar: Calendar
    ) -> [Date] {
        guard let rule = recurrenceRule else {
            // One-time income: return startDate if within range
            return (startDate >= rangeStart && startDate <= rangeEnd) ? [startDate] : []
        }

        // IMPORTANT: Generate from startDate (anchor), then filter to window.
        // This preserves correct weekly/monthly alignment (e.g., salary on the 1st stays on the 1st).
        let allOccurrences = rule.generateOccurrences(
            from: startDate,
            until: rangeEnd,
            calendar: calendar
        )

        // Filter to requested window
        return allOccurrences.filter { $0 >= rangeStart }
    }
}
