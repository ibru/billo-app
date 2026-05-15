//  Created by Jiri Urbasek on 11/26/25.

import SwiftData
import Foundation
import Observation

@MainActor
@Observable
final class BillsModel {
    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let currentDate: () -> Date
    @ObservationIgnored private let notificationCoordinator: NotificationCoordinating
    @ObservationIgnored private let notificationPreferences: NotificationPreferencesReading
    @ObservationIgnored private let badgeCalculator: BadgeCalculator

    private(set) var bills: [Bill] = []
    private(set) var incomes: [Income] = []
    private(set) var sections: BillsListSections = .empty
    private(set) var incomeOccurrences: [IncomeOccurrence] = []

    init(
        modelContext: ModelContext,
        calendar: Calendar = .current,
        currentDate: @escaping () -> Date = { Date() },
        notificationCoordinator: NotificationCoordinating,
        notificationPreferences: NotificationPreferencesReading
    ) {
        self.modelContext = modelContext
        self.calendar = calendar
        self.currentDate = currentDate
        self.notificationCoordinator = notificationCoordinator
        self.notificationPreferences = notificationPreferences
        self.badgeCalculator = BadgeCalculator(calendar: calendar, baseHorizonDays: 90)
    }

    func refresh() throws {
        try refresh(monthsAhead: 3)
    }

    func refresh(monthsAhead: Int) throws {
        // Capture a single wall-clock read so the materializer's "past upper bound"
        // and the view-build's "today" agree even if the clock crosses midnight
        // mid-refresh. Without this, yesterday's row can vanish or get double-counted.
        let referenceDate = currentDate()

        // Fetch both bills and incomes from same context for data consistency
        let billDescriptor = FetchDescriptor<Bill>(sortBy: [SortDescriptor(\.dueDate)])
        bills = try modelContext.fetch(billDescriptor)

        let incomeDescriptor = FetchDescriptor<Income>(sortBy: [SortDescriptor(\.startDate)])
        incomes = try modelContext.fetch(incomeDescriptor)

        // Lazy steady-state materialization: ensure every past occurrence for an
        // active income is recorded as a snapshot row. This is the only place that
        // backfills "missed" past dates that accumulated since the last refresh.
        try materializeMissingPastOccurrences(today: referenceDate)

        let occurrenceDescriptor = FetchDescriptor<IncomeOccurrence>(sortBy: [SortDescriptor(\.date)])
        incomeOccurrences = try modelContext.fetch(occurrenceDescriptor)

        let horizon = calendar.date(byAdding: .month, value: monthsAhead, to: referenceDate) ?? referenceDate
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? referenceDate
        let monthStart = calendar.dateInterval(of: .month, for: referenceDate)?.start ?? referenceDate
        let rangeStart = min(weekStart, monthStart)

        let incomeItems = buildIncomeOccurrenceItems(
            rangeStart: rangeStart,
            rangeEnd: horizon,
            persisted: incomeOccurrences,
            incomes: incomes,
            referenceDate: referenceDate
        )

        sections = BillsListSections.build(
            from: bills,
            incomeOccurrenceItems: incomeItems,
            referenceDate: referenceDate,
            calendar: calendar,
            monthsAhead: monthsAhead
        )
        Logger.log(
            "Refreshed bills: \(bills.count), incomes: \(incomes.count), incomeOccurrences: \(incomeOccurrences.count), months: \(monthsAhead)",
            level: .debug
        )
    }

    /// Single source of truth for "what income occurrences should I show for range X?".
    /// Returns persisted past rows (frozen snapshots) and computed future views,
    /// de-duplicated by `occurrenceKey` so CloudKit-induced duplicates collapse to one.
    ///
    /// `referenceDate` defaults to a fresh wall-clock read; pass an explicit value
    /// from the caller's outer pipeline (e.g. `BillsCalendarView.refreshData`) when
    /// you need the past/future boundary to agree with another `Date()` capture
    /// taken upstream — this prevents a midnight crossing between the two reads.
    func incomeOccurrenceItems(
        rangeStart: Date,
        rangeEnd: Date,
        referenceDate: Date? = nil
    ) -> [IncomeOccurrenceItem] {
        buildIncomeOccurrenceItems(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            persisted: incomeOccurrences,
            incomes: incomes,
            referenceDate: referenceDate ?? currentDate()
        )
    }

    private func materializeMissingPastOccurrences(today: Date) throws {
        let materializer = IncomeOccurrenceMaterializer()

        // One global fetch of `IncomeOccurrence` rows up front. Going through
        // the main store rather than each income's `materializedOccurrences`
        // inverse sidesteps a CloudKit eventual-consistency window where the
        // rows have synced to this device but the inverse hasn't propagated
        // yet — without that we'd re-insert duplicates at the same key.
        let allOccurrences = try modelContext.fetch(FetchDescriptor<IncomeOccurrence>())
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
                context: modelContext
            )
        }

        try modelContext.save()
    }

    private func buildIncomeOccurrenceItems(
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

    func markPaid(
        _ occurrence: BillOccurrence,
        amount: Decimal? = nil,
        date: Date? = nil,
        confirmationNumber: String? = nil
    ) async throws {
        let paidAmount = amount ?? occurrence.amount
        Logger.log("Marking paid: \(occurrence.name), occurrence: \(occurrence.dueDate), amount: \(paidAmount)", level: .info)
        let recorder = PaymentRecorder()

        _ = try await recorder.recordPayment(
            for: occurrence.bill,
            occurrenceDate: occurrence.dueDate,
            amount: amount ?? occurrence.amount,
            datePaid: date ?? currentDate(),
            confirmationNumber: confirmationNumber,
            calendar: calendar,
            context: modelContext,
            notificationCoordinator: notificationCoordinator,
            badgeCalculator: badgeCalculator,
            badgeMode: notificationPreferences.badgeMode,
            allBills: bills,
            currentDate: currentDate
        )

        try refresh()
        await refreshNotifications()
    }

    func addBill(_ bill: Bill) async throws {
        Logger.log("Adding bill: \(bill.name)", level: .info)
        modelContext.insert(bill)
        try modelContext.save()
        try refresh()
        await refreshNotifications()
    }

    func markUnpaid(_ occurrence: BillOccurrence) async throws {
        Logger.log("Marking unpaid: \(occurrence.name), occurrence: \(occurrence.dueDate)", level: .info)
        let issued = occurrence.bill.issuedOccurrence(for: occurrence.dueDate, calendar: calendar)
        let payments = issued?.safePaymentEntries ?? []

        for payment in payments {
            modelContext.delete(payment)
        }

        if let issued, payments.isEmpty == false {
            let todayStart = calendar.startOfDay(for: currentDate())
            let dueStart = calendar.startOfDay(for: issued.dueDate)
            if dueStart > todayStart {
                modelContext.delete(issued)
            }
        }
        try modelContext.save()

        // Refresh data first, then recalculate badge with fresh state
        try refresh()
        await refreshNotifications()
    }

    /// Deletes a payment entry and refreshes notifications/badge.
    /// Use this centralized method instead of direct modelContext.delete() to ensure
    /// notifications and badge counts stay in sync.
    func deletePaymentEntry(_ payment: PaymentEntry) async throws {
        Logger.log("Deleting payment entry: \(payment.amount) paid on \(payment.datePaid)", level: .info)

        let issued = payment.issuedOccurrence
        let remainingPayments = issued?.safePaymentEntries.filter { $0 !== payment } ?? []

        modelContext.delete(payment)

        // If no remaining payments and due date is in the future, delete the IssuedOccurrence
        if let issued, remainingPayments.isEmpty {
            let todayStart = calendar.startOfDay(for: currentDate())
            let dueStart = calendar.startOfDay(for: issued.dueDate)
            if dueStart > todayStart {
                modelContext.delete(issued)
            }
        }

        try modelContext.save()
        try refresh()
        await refreshNotifications()
    }

    func deleteBill(_ bill: Bill) async throws {
        Logger.log("Deleting bill: \(bill.name)", level: .info)
        modelContext.delete(bill)
        try modelContext.save()
        try refresh()
        await refreshNotifications()
    }

    func updateBill(_ bill: Bill, preEditSnapshot: BillSnapshot? = nil) async throws {
        if let preEditSnapshot {
            try issuePastDueOccurrencesIfNeeded(for: bill, preEditSnapshot: preEditSnapshot)
        }
        try modelContext.save()
        try refresh()
        await refreshNotifications()
    }

    // MARK: - Income Management

    func addIncome(_ income: Income) async throws {
        Logger.log("Adding income: \(income.name), amount: \(income.amount)", level: .info)
        modelContext.insert(income)
        try modelContext.save()
        try refresh()
    }

    func deleteIncome(_ income: Income) async throws {
        Logger.log("Deleting income: \(income.name)", level: .info)

        // Capture the snapshot before delete so any past dates that aren't yet
        // materialized get a frozen row. After `.nullify` runs, the row's
        // `income` reference becomes nil but the snapshot survives.
        let snapshot = IncomeSnapshot(income: income)
        try IncomeOccurrenceMaterializer().materializePastOccurrences(
            for: snapshot,
            income: income,
            upTo: currentDate(),
            calendar: calendar,
            context: modelContext
        )

        modelContext.delete(income)
        try modelContext.save()
        try refresh()
    }

    func updateIncome(_ income: Income, draft: IncomeDraft) async throws {
        // Validate before any mutation so a bad draft cannot leave the live
        // model partially updated. Mirrors the invariants `Income.create`
        // enforces on the add path. `validated.name` is trimmed.
        let validated = try Income.validate(
            name: draft.name,
            amount: draft.amount,
            startDate: draft.startDate,
            recurrenceRule: draft.recurrenceRule
        )

        // Snapshot the *pre-edit* state so the materializer freezes past dates
        // with the old amount and old schedule before we apply the new values.
        let snapshot = IncomeSnapshot(income: income)
        try IncomeOccurrenceMaterializer().materializePastOccurrences(
            for: snapshot,
            income: income,
            upTo: currentDate(),
            calendar: calendar,
            context: modelContext
        )

        let now = currentDate()
        income.name = validated.name
        income.amount = validated.amount
        income.startDate = validated.startDate
        income.recurrenceRule = validated.recurrenceRule
        income.lastUpdatedDate = now
        // Bump the schedule-effective boundary so the chained `refresh()`'s
        // materializer (which sees the *new* snapshot) cannot project the new
        // schedule onto dates that were already past at this moment.
        //
        // Day-normalize the boundary so it represents the **edit day**, not
        // the precise edit instant. Without this, a same-day edit (e.g. noon
        // edit on Apr 1 where the salary is at Apr 1 00:00) would compare
        // `Apr 1 00:00 < Apr 1 12:00` and skip Apr 1 forever on next refresh.
        income.materializationStartDate = calendar.startOfDay(for: now)

        try modelContext.save()
        try refresh()
    }

    func skipIncomeOccurrence(_ occurrence: IncomeOccurrence) async throws {
        Logger.log(
            "Skipping income occurrence: \(occurrence.incomeName) on \(occurrence.date)",
            level: .info
        )
        // Mark every row sharing this occurrenceKey as excluded so the operation
        // is logically per-key. Without this, a CloudKit duplicate at the same key
        // would leave the un-skipped twin visible after a refresh.
        let key = occurrence.occurrenceKey
        let descriptor = FetchDescriptor<IncomeOccurrence>(
            predicate: #Predicate<IncomeOccurrence> { $0.occurrenceKey == key }
        )
        let now = currentDate()
        let allWithKey = try modelContext.fetch(descriptor)
        for row in allWithKey where row.isExcluded == false {
            row.isExcluded = true
            row.excludedDate = now
        }
        try modelContext.save()
        try refresh()
    }

    /// Corrects the amount on a single past income occurrence. Only mutates
    /// `incomeAmount` on the targeted snapshot row; the parent `Income` and
    /// all other materialized rows are untouched.
    ///
    /// Validation mirrors `Income.create` — amount must be `> 0`. Throws
    /// `IncomeValidationError.nonPositiveAmount` otherwise.
    func editIncomeOccurrenceAmount(
        _ occurrence: IncomeOccurrence,
        amount: Decimal
    ) async throws {
        guard amount > 0 else {
            throw IncomeValidationError.nonPositiveAmount
        }
        Logger.log(
            "Editing income occurrence amount: \(occurrence.incomeName) on \(occurrence.date) → \(amount)",
            level: .info
        )
        occurrence.incomeAmount = amount
        try modelContext.save()
        try refresh()
    }

    /// Deletes a single past income occurrence. Implemented as a soft-skip
    /// (sets `isExcluded = true`) rather than a hard delete because the
    /// materializer would otherwise re-create the row at the next refresh —
    /// its `occurrenceKey` is no longer in `existingKeys`, and the date is
    /// `>= materializationStartDate`, so it would slot right back in.
    ///
    /// Soft-skip survives the materializer (the row stays in the store with
    /// `isExcluded == true`, which is treated as "already materialized") and
    /// is invisible to all view-layer reads. Delegates to the existing
    /// per-key skip path so CloudKit duplicates collapse correctly.
    func deleteIncomeOccurrence(_ occurrence: IncomeOccurrence) async throws {
        Logger.log(
            "Deleting income occurrence: \(occurrence.incomeName) on \(occurrence.date)",
            level: .info
        )
        try await skipIncomeOccurrence(occurrence)
    }

    private func calculateUnpaidCount() -> Int {
        // Use BadgeCalculator to respect user's badge window preference
        return badgeCalculator.calculateBadgeCount(
            bills: bills,
            badgeMode: notificationPreferences.badgeMode,
            referenceDate: currentDate()
        )
    }

    private func refreshNotifications() async {
        // Notification failures should not block data changes.
        do {
            try await notificationCoordinator.refreshAllNotifications(for: bills)
        } catch {
            Logger.log("Failed to refresh notifications: \(error)", level: .error)
        }
    }

    private func issuePastDueOccurrencesIfNeeded(
        for bill: Bill,
        preEditSnapshot: BillSnapshot
    ) throws {
        let todayStart = calendar.startOfDay(for: currentDate())
        let pastOccurrences = preEditSnapshot.generateOccurrences(until: todayStart, calendar: calendar)
            .filter { $0 < todayStart }

        guard pastOccurrences.isEmpty == false else { return }

        // Skip already-paid occurrences since issued snapshots hold payment history
        let fullyPaidDates = Set(
            bill.safeIssuedOccurrences
                .filter { bill.isFullyPaid(for: $0.dueDate, calendar: calendar) }
                .map { calendar.startOfDay(for: $0.dueDate) }
        )

        let existingKeys = Set(bill.safeIssuedOccurrences.map(\.occurrenceKey))
        var insertedKeys = Set<String>()

        for dueDate in pastOccurrences {
            let dayStart = calendar.startOfDay(for: dueDate)
            // Skip if already fully paid
            if fullyPaidDates.contains(dayStart) { continue }

            let key = preEditSnapshot.occurrenceKey(for: dueDate)
            if existingKeys.contains(key) || insertedKeys.contains(key) { continue }

            let issued = IssuedOccurrence(
                occurrenceKey: key,
                dueDate: dueDate,
                billName: preEditSnapshot.name,
                billAmount: preEditSnapshot.amount,
                billCurrencyCode: preEditSnapshot.currencyCode,
                billAccountIdentifier: preEditSnapshot.accountIdentifier,
                billNotes: preEditSnapshot.notes,
                billCategoryRawValue: preEditSnapshot.categoryIdentifierRawValue,
                bill: bill
            )
            modelContext.insert(issued)
            insertedKeys.insert(key)
        }
    }
}

// MARK: - Income Edit Draft

/// Captured form values from `IncomeEditView`. Passed into
/// `BillsModel.updateIncome(_:draft:)` so mutation happens in one place and
/// the pre-edit `IncomeSnapshot` can be captured before the live `Income` mutates.
struct IncomeDraft {
    let name: String
    let amount: Decimal
    let startDate: Date
    let recurrenceRule: RecurrenceRule?
}

// MARK: - Protocol Conformance

extension BillsModel: BillsRefreshing { }
