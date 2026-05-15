//  Created by Jiri Urbasek on 05/07/26.

import Foundation

/// Pre-edit projection of an `Income` used to materialize past `IncomeOccurrence`
/// rows before the live `Income` mutates.
///
/// Mirrors `BillSnapshot` (`Bill.swift`): occurrence dates and amounts are anchored
/// at the snapshot's own `startDate`/`amount`/`recurrenceRule`, so a schedule edit
/// (e.g. moving a salary from the 1st to the 15th) still materializes the *old*
/// dates with the *old* amount before the new schedule takes effect.
struct IncomeSnapshot {
    let stableID: String
    let name: String
    let amount: Decimal
    let currencyCode: String
    let startDate: Date
    let recurrenceRule: RecurrenceRuleSnapshot?
    /// The `Income.materializationStartDate` at snapshot time. Used by the
    /// materializer as the lower bound for newly-inserted rows; see the field
    /// on `Income` for the full semantics.
    let materializationStartDate: Date

    init(income: Income) {
        assert(!income.stableID.isEmpty, "IncomeSnapshot requires Income.stableID to be set")
        self.stableID = income.stableID
        self.name = income.name
        self.amount = income.amount
        self.currencyCode = income.currencyCode
        self.startDate = income.startDate
        self.recurrenceRule = income.recurrenceRule.map { RecurrenceRuleSnapshot(rule: $0) }
        self.materializationStartDate = income.materializationStartDate
    }

    /// Generates occurrence dates from the snapshot's `startDate` up to (but not
    /// including) `endDate`. Anchored at `startDate` so weekday/day-of-month
    /// alignment is preserved across edits.
    func generateOccurrences(
        until endDate: Date,
        calendar: Calendar
    ) -> [Date] {
        guard let rule = recurrenceRule else {
            return (startDate < endDate) ? [startDate] : []
        }

        return rule.generateOccurrences(from: startDate, until: endDate, calendar: calendar)
    }

    /// Builds the deterministic occurrence key for `occurrenceDate`.
    ///
    /// Delegates to the shared `OccurrenceKey.make(...)`. Identity is UTC-day
    /// keyed — see `Date.utcDayKey`'s doc note for the timezone-drift contract.
    func occurrenceKey(for occurrenceDate: Date) -> String {
        OccurrenceKey.make(stableID: stableID, date: occurrenceDate)
    }
}
