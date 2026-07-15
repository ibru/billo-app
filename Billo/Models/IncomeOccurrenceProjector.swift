//  Created by Jiri Urbasek on 07/09/26.

import Foundation
import SwiftData

/// Single source of truth for "what income occurrences exist in range X?".
///
/// Extracted from `BillsModel` so read-only consumers (e.g. `ChartsModel`) can
/// project the same income ledger — persisted past snapshots (frozen, possibly
/// user-edited or excluded) plus computed future views — without duplicating
/// the dedupe and past/future boundary rules.
@MainActor
struct IncomeOccurrenceProjector {
    let calendar: Calendar

    // MARK: - Materialization

    /// Lazy steady-state materialization: ensures every past occurrence for an
    /// active income is recorded as a persisted `IncomeOccurrence` snapshot.
    /// Idempotent — existing rows (including soft-skipped ones) are left alone.
    ///
    /// Uses one global fetch of `IncomeOccurrence` rows up front. Going through
    /// the main store rather than each income's `materializedOccurrences`
    /// inverse sidesteps a CloudKit eventual-consistency window where the
    /// rows have synced to this device but the inverse hasn't propagated
    /// yet — without that we'd re-insert duplicates at the same key.
    func materializePastOccurrences(
        for incomes: [Income],
        upTo today: Date,
        context: ModelContext
    ) throws {
        let materializer = IncomeOccurrenceMaterializer()

        let allOccurrences = try context.fetch(FetchDescriptor<IncomeOccurrence>())
        let existingByStableID = Dictionary(grouping: allOccurrences) { row in
            OccurrenceKey.stableID(from: row.occurrenceKey) ?? ""
        }

        for income in incomes {
            // The materializer is idempotent — running it for every income (even
            // ones with an already-passed endDate) is the safe simple rule.
            let snapshot = IncomeSnapshot(income: income)
            let existingForIncome = existingByStableID[income.stableID] ?? []
            try materializer.materializePastOccurrences(
                for: snapshot,
                income: income,
                existingRows: existingForIncome,
                upTo: today,
                calendar: calendar,
                context: context
            )
        }

        // Steady state inserts nothing — skip the save machinery (and the
        // CloudKit export scheduling it pokes) on this read-mostly path.
        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - Projection

    /// Returns persisted past rows (frozen snapshots) and computed future views,
    /// de-duplicated by `occurrenceKey` so CloudKit-induced duplicates collapse to one.
    func items(
        rangeStart: Date,
        rangeEnd: Date,
        persisted: [IncomeOccurrence],
        incomes: [Income],
        referenceDate: Date
    ) -> [IncomeOccurrenceItem] {
        let todayStart = calendar.startOfDay(for: referenceDate)
        let pastUpperBound = min(todayStart, rangeEnd)

        // Persisted past: half-open `[rangeStart, pastUpperBound)`.
        // Dedupe groups must include rows in *all* exclusion states so that a
        // skip on one row of a CloudKit-duplicate pair suppresses the whole key.
        // The dedupe step returns a per-key visibility flag instead of mutating
        // the model from a read-time path.
        let persistedInRange = persisted.filter { occurrence in
            occurrence.date >= rangeStart && occurrence.date < pastUpperBound
        }

        let dedupedPersisted = dedupeByOccurrenceKey(persistedInRange)
        let persistedViews = dedupedPersisted
            .filter(\.isVisible)
            .map { IncomeOccurrenceItem(model: $0.row) }

        // Computed future: `[max(today, rangeStart), rangeEnd)` from live incomes,
        // skipping incomes whose endDate has already passed.
        var futureViews: [IncomeOccurrenceItem] = []
        let futureStart = max(todayStart, rangeStart)
        if futureStart < rangeEnd {
            for income in incomes where isIncomeActive(income, on: todayStart) {
                let dates = income.generateOccurrences(
                    from: futureStart,
                    until: rangeEnd,
                    calendar: calendar
                )
                futureViews.append(contentsOf: dates.map { IncomeOccurrenceItem(future: income, on: $0) })
            }
        }

        return (persistedViews + futureViews).sorted { $0.date < $1.date }
    }

    private func isIncomeActive(_ income: Income, on todayStart: Date) -> Bool {
        guard let rule = income.recurrenceRule, rule.endConditionType == .endDate else {
            return true
        }
        guard let endDate = rule.endDate else { return true }
        return endDate >= todayStart
    }

    // MARK: - Dedupe

    /// Dedupe outcome for a single `occurrenceKey` group.
    ///
    /// `row` is the deterministic winner (earliest `createdDate`, then string-
    /// compared `persistentModelID` as a stable last-resort tiebreak).
    /// `isVisible == false` when *any* row in the group is excluded — this
    /// covers the late-arriving CloudKit duplicate case where the un-skipped
    /// twin would otherwise win and resurrect the skipped occurrence.
    struct DedupeResult {
        let row: IncomeOccurrence
        let isVisible: Bool
    }

    private func dedupeByOccurrenceKey(_ rows: [IncomeOccurrence]) -> [DedupeResult] {
        var groups: [String: [IncomeOccurrence]] = [:]
        for row in rows {
            groups[row.occurrenceKey, default: []].append(row)
        }
        return groups.values.map { siblings in
            var winner = siblings[0]
            for candidate in siblings.dropFirst() where shouldReplace(existing: winner, with: candidate) {
                winner = candidate
            }
            let groupExcluded = siblings.contains(where: \.isExcluded)
            return DedupeResult(row: winner, isVisible: groupExcluded == false)
        }
    }

    private func shouldReplace(existing: IncomeOccurrence, with candidate: IncomeOccurrence) -> Bool {
        if candidate.createdDate != existing.createdDate {
            return candidate.createdDate < existing.createdDate
        }
        // Last-resort tiebreaker: `String(describing: persistentModelID)` is
        // stable within a process; CloudKit re-IDs on sync are documented at
        // `Bill.swift:98` and tolerated because both devices will eventually
        // converge on the same winning createdDate.
        return String(describing: candidate.persistentModelID) <
               String(describing: existing.persistentModelID)
    }
}
