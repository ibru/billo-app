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
    var stableID: String = UUID().uuidString
    var name: String = ""
    var amount: Decimal = 0
    var currencyCode: String = "USD"
    var startDate: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \RecurrenceRule.income)
    var recurrenceRule: RecurrenceRule?
    var createdDate: Date = Date()
    var lastUpdatedDate: Date = Date()

    /// Earliest **day** (stored as the start-of-day `Date` for that day) for
    /// which this Income's current schedule should produce materialized rows.
    /// Set on creation to `min(startDate, startOfDay(createdDate))` so a
    /// backdated new income still backfills from `startDate`. Bumped to
    /// `startOfDay(now)` whenever `BillsModel.updateIncome(_:draft:)` mutates
    /// the schedule — this is what prevents a 1st → 5th edit on Apr 10 from
    /// retroactively inserting an Apr 5 row at the new amount, while still
    /// allowing the *same-day* row (occurrence at 00:00, edited later) to be
    /// frozen on the next-day refresh.
    ///
    /// Default at the property declaration is `.distantPast` so SwiftData
    /// lightweight migration on existing records preserves the pre-field
    /// behavior (all past dates eligible). Brand-new records always go
    /// through `init`, which sets the real value.
    var materializationStartDate: Date = Date.distantPast

    @Relationship(deleteRule: .nullify, inverse: \IncomeOccurrence.income)
    var materializedOccurrences: [IncomeOccurrence]? = []

    init(
        name: String,
        amount: Decimal,
        currencyCode: String = Locale.current.currency?.identifier ?? "USD",
        startDate: Date,
        recurrenceRule: RecurrenceRule? = nil,
        stableID: String? = nil,
        calendar: Calendar = .current
    ) {
        let now = Date()
        self.stableID = stableID ?? UUID().uuidString
        self.name = name
        self.amount = amount
        self.currencyCode = currencyCode
        self.startDate = startDate
        self.recurrenceRule = recurrenceRule
        self.createdDate = now
        self.lastUpdatedDate = now
        // Day-normalize the boundary so a same-day comparison against a
        // midnight occurrence date (e.g. salary at Apr 1 00:00 vs a noon edit
        // on Apr 1) passes the materializer's `>=` check. Uses the passed-in
        // calendar — matching Bill.init's signature — so tests pinning to UTC
        // get UTC normalization and production gets the user's local calendar.
        self.materializationStartDate = min(startDate, calendar.startOfDay(for: now))
    }
}

// MARK: - Validated Factory

extension Income {
    /// Validated, normalized fields ready to be assigned to an `Income`. Returned
    /// by `validate(...)` so both the create-new and edit-existing paths can run
    /// the same invariant check and reuse the trimmed-name normalization without
    /// duplicating code.
    struct ValidatedFields {
        let name: String
        let amount: Decimal
        let startDate: Date
        let recurrenceRule: RecurrenceRule?
    }

    /// Validates the candidate fields and returns a normalized `ValidatedFields`
    /// (currently: name is trimmed). Throws `IncomeValidationError` if any
    /// invariant is violated.
    ///
    /// This is the single source of truth for `Income`'s domain rules. Call it
    /// from any path that mutates `name`/`amount`/`startDate`/`recurrenceRule` —
    /// `Income.create(...)` for new rows and `BillsModel.updateIncome(_:draft:)`
    /// for edits. `@MainActor` because `RecurrenceRule` is a SwiftData `@Model`
    /// whose property accesses are main-actor-isolated.
    @MainActor
    static func validate(
        name: String,
        amount: Decimal,
        startDate: Date,
        recurrenceRule: RecurrenceRule?
    ) throws -> ValidatedFields {
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

        return ValidatedFields(
            name: trimmedName,
            amount: amount,
            startDate: startDate,
            recurrenceRule: recurrenceRule
        )
    }

    /// Creates a validated Income. Throws IncomeValidationError if validation fails.
    /// Use this instead of direct init to ensure data integrity.
    /// Currency code should come from AppSettingsModel.currencyCode
    @MainActor
    static func create(
        name: String,
        amount: Decimal,
        currencyCode: String,
        startDate: Date,
        recurrenceRule: RecurrenceRule? = nil,
        calendar: Calendar = .current
    ) throws -> Income {
        let validated = try validate(
            name: name,
            amount: amount,
            startDate: startDate,
            recurrenceRule: recurrenceRule
        )

        return Income(
            name: validated.name,
            amount: validated.amount,
            currencyCode: currencyCode,
            startDate: validated.startDate,
            recurrenceRule: validated.recurrenceRule,
            calendar: calendar
        )
    }
}

// MARK: - Occurrence Generation

extension Income {
    /// Generate income dates within a range, delegating to RecurrenceRule.
    /// Range semantics are half-open: `[from, until)`.
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
            return (startDate >= rangeStart && startDate < rangeEnd) ? [startDate] : []
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
