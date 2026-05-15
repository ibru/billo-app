//  Created by Jiri Urbasek on 12/10/25.

import Foundation
import SwiftData

/// Persisted snapshot of a single income occurrence on a given date.
///
/// Mirrors the `IssuedOccurrence` pattern (`Bill` history): once a past income
/// occurrence has been materialized, edits to the live `Income` no longer rewrite
/// it, and deleting the `Income` nullifies the relationship so the row survives
/// in the historical ledger.
///
/// `isExcluded` is a soft-skip flag set by user-initiated "mark as not received"
/// actions; the materializer treats existing rows (skipped or not) as already
/// materialized, so a skipped occurrence cannot be resurrected by a refresh.
@Model
final class IncomeOccurrence {
    var occurrenceKey: String = ""        // "<income.stableID>:<UTC YYYY-MM-DD>"
    var date: Date = Date()
    var incomeName: String = ""           // snapshot at materialization time
    var incomeAmount: Decimal = 0
    var incomeCurrencyCode: String = "USD"
    var isExcluded: Bool = false
    var excludedDate: Date?
    var createdDate: Date = Date()

    // CloudKit requires all relationships to be optional with explicit inverses.
    // Inverse declared on Income.materializedOccurrences with deleteRule: .nullify,
    // so deleting the Income preserves this snapshot.
    var income: Income?

    init(
        occurrenceKey: String,
        date: Date,
        incomeName: String,
        incomeAmount: Decimal,
        incomeCurrencyCode: String,
        income: Income?
    ) {
        self.occurrenceKey = occurrenceKey
        self.date = date
        self.incomeName = incomeName
        self.incomeAmount = incomeAmount
        self.incomeCurrencyCode = incomeCurrencyCode
        self.income = income
        self.createdDate = Date()
        self.isExcluded = false
    }
}
