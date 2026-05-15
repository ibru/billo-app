//  Created by Jiri Urbasek on 05/07/26.

import Foundation
import SwiftData

/// Display-time projection of an income occurrence.
///
/// Calendars and lists render `IncomeOccurrenceItem` rather than the persisted
/// `IncomeOccurrence` model so the same row type can stand in for both a frozen
/// past snapshot (`isPersisted == true`) and a computed future projection
/// (`isPersisted == false`). This keeps previews, tests, and grid builders free
/// of `ModelContainer` setup.
struct IncomeOccurrenceItem: Identifiable, Hashable {
    /// Stable identifier across both persisted and computed views.
    ///
    /// `key` matches the `IncomeOccurrence.occurrenceKey` for persisted rows and
    /// uses a `"future:..."` prefix for computed projections so the two spaces
    /// stay disjoint when they coexist in the same range. `key` already encodes
    /// the UTC day, which makes the identity one-dimensional — no separate date
    /// component is needed.
    struct OccurrenceID: Hashable {
        let key: String

        init(key: String) {
            self.key = key
        }
    }

    let id: OccurrenceID
    let date: Date
    let name: String
    let amount: Decimal
    let currencyCode: String
    let isPersisted: Bool

    /// Optional reference to the live `Income` that produced this view. Always
    /// set for future projections; `nil` for persisted past rows whose source
    /// `Income` has been deleted.
    let incomeID: PersistentIdentifier?

    /// Reference to the persisted `IncomeOccurrence` row, when one exists.
    /// `nil` for future projections. Used by the per-occurrence skip action.
    let occurrenceID: PersistentIdentifier?

    init(model: IncomeOccurrence) {
        self.id = OccurrenceID(key: model.occurrenceKey)
        self.date = model.date
        self.name = model.incomeName
        self.amount = model.incomeAmount
        self.currencyCode = model.incomeCurrencyCode
        self.isPersisted = true
        self.incomeID = model.income?.persistentModelID
        self.occurrenceID = model.persistentModelID
    }

    init(future income: Income, on date: Date) {
        // Future projections live in a disjoint key-space from persisted rows
        // so they can coexist in the same range without colliding. The
        // canonical `OccurrenceKey.make(...)` shape is wrapped with a
        // `future:` prefix that `Income.stableID` (a UUID) cannot produce.
        let key = "future:" + OccurrenceKey.make(stableID: income.stableID, date: date)
        self.id = OccurrenceID(key: key)
        self.date = date
        self.name = income.name
        self.amount = income.amount
        self.currencyCode = income.currencyCode
        self.isPersisted = false
        self.incomeID = income.persistentModelID
        self.occurrenceID = nil
    }
}

// MARK: - Future Generation

extension IncomeOccurrenceItem {
    /// Generates `IncomeOccurrenceItem` projections for a date range from live
    /// `Income` records. Used for ranges entirely in the future, or as the
    /// computed-future tail by `BillsModel.incomeOccurrenceItems(...)`.
    @MainActor
    static func generate(
        from incomes: [Income],
        rangeStart: Date,
        rangeEnd: Date,
        calendar: Calendar
    ) -> [IncomeOccurrenceItem] {
        incomes.flatMap { income in
            income.generateOccurrences(from: rangeStart, until: rangeEnd, calendar: calendar)
                .map { IncomeOccurrenceItem(future: income, on: $0) }
        }
    }
}
