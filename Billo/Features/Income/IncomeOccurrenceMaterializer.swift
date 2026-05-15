//  Created by Jiri Urbasek on 05/07/26.

import Foundation
import SwiftData

/// Inserts `IncomeOccurrence` rows for past dates produced by an `IncomeSnapshot`.
///
/// Idempotent: rows already present at a key (including soft-skipped ones)
/// are left alone. Snapshot-and-go past freezing comes from
/// `snapshot.materializationStartDate` — see the field's docstring on
/// `Income` for the full contract; the materializer just enforces
/// `occurrenceDate >= materializationStartDate`.
///
/// `existingRows` is passed in by callers (rather than read off the
/// `Income.materializedOccurrences` relationship inverse) so CloudKit
/// eventual-consistency windows can't trick the materializer into duplicate
/// inserts. Past is `< startOfDay(today)`; today's row stays in the
/// future generator so same-day edits remain mutable until midnight.
struct IncomeOccurrenceMaterializer {
    @MainActor
    @discardableResult
    func materializePastOccurrences(
        for snapshot: IncomeSnapshot,
        income: Income,
        existingRows: [IncomeOccurrence],
        upTo today: Date,
        calendar: Calendar,
        context: ModelContext
    ) throws -> [IncomeOccurrence] {
        let pastUpperBound = calendar.startOfDay(for: today)
        let occurrenceDates = snapshot.generateOccurrences(
            until: pastUpperBound,
            calendar: calendar
        )

        guard occurrenceDates.isEmpty == false else { return [] }

        let existingKeys = Set(existingRows.map(\.occurrenceKey))
        let scheduleEffectiveSince = snapshot.materializationStartDate

        var inserted: [IncomeOccurrence] = []

        for occurrenceDate in occurrenceDates {
            let key = snapshot.occurrenceKey(for: occurrenceDate)
            if existingKeys.contains(key) { continue }

            // Day-normalized boundary defined by the snapshot — see
            // `Income.materializationStartDate`.
            if occurrenceDate < scheduleEffectiveSince { continue }

            let row = IncomeOccurrence(
                occurrenceKey: key,
                date: occurrenceDate,
                incomeName: snapshot.name,
                incomeAmount: snapshot.amount,
                incomeCurrencyCode: snapshot.currencyCode,
                income: income
            )
            context.insert(row)
            inserted.append(row)
        }

        return inserted
    }

    /// Convenience overload that fetches existing rows from the model context
    /// by `occurrenceKey` prefix. Use this from one-off mutation paths
    /// (`updateIncome`, `deleteIncome`); from `refresh()`, hoist a single
    /// global fetch and call the explicit `existingRows:` variant per income.
    @MainActor
    @discardableResult
    func materializePastOccurrences(
        for snapshot: IncomeSnapshot,
        income: Income,
        upTo today: Date,
        calendar: Calendar,
        context: ModelContext
    ) throws -> [IncomeOccurrence] {
        let existing = try fetchExistingRows(forStableID: snapshot.stableID, in: context)
        return try materializePastOccurrences(
            for: snapshot,
            income: income,
            existingRows: existing,
            upTo: today,
            calendar: calendar,
            context: context
        )
    }

    /// Returns all `IncomeOccurrence` rows whose `occurrenceKey` belongs to
    /// `stableID`. Goes through the main store rather than a relationship
    /// inverse so it stays correct during a CloudKit inverse-propagation lag.
    @MainActor
    func fetchExistingRows(
        forStableID stableID: String,
        in context: ModelContext
    ) throws -> [IncomeOccurrence] {
        let prefix = OccurrenceKey.prefix(forStableID: stableID)
        let descriptor = FetchDescriptor<IncomeOccurrence>(
            predicate: #Predicate<IncomeOccurrence> { row in
                row.occurrenceKey.starts(with: prefix)
            }
        )
        return try context.fetch(descriptor)
    }
}
