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
    @ObservationIgnored private let incomeProjector: IncomeOccurrenceProjector
    @ObservationIgnored private let analyticsCapture: (AnalyticsEvent) -> Void

    private(set) var bills: [Bill] = []
    private(set) var incomes: [Income] = []
    private(set) var sections: BillsListSections = .empty
    private(set) var incomeOccurrences: [IncomeOccurrence] = []
    /// Rebuilt on every `refresh()` (launch, mutations, app-active) so views
    /// read a precomputed dictionary instead of counting during body updates.
    private(set) var categoryUsageCounts: [CategoryIdentifier: Int] = [:]

    init(
        modelContext: ModelContext,
        calendar: Calendar = .current,
        currentDate: @escaping () -> Date = { Date() },
        notificationCoordinator: NotificationCoordinating,
        notificationPreferences: NotificationPreferencesReading,
        analyticsCapture: @escaping (AnalyticsEvent) -> Void = { _ in }
    ) {
        self.modelContext = modelContext
        self.calendar = calendar
        self.currentDate = currentDate
        self.notificationCoordinator = notificationCoordinator
        self.notificationPreferences = notificationPreferences
        self.analyticsCapture = analyticsCapture
        self.badgeCalculator = BadgeCalculator(calendar: calendar, baseHorizonDays: 90)
        self.incomeProjector = IncomeOccurrenceProjector(calendar: calendar)
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
        categoryUsageCounts = CategoryCatalog.usageCounts(bills: bills)

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
        try incomeProjector.materializePastOccurrences(
            for: incomes,
            upTo: today,
            context: modelContext
        )
    }

    private func buildIncomeOccurrenceItems(
        rangeStart: Date,
        rangeEnd: Date,
        persisted: [IncomeOccurrence],
        incomes: [Income],
        referenceDate: Date
    ) -> [IncomeOccurrenceItem] {
        incomeProjector.items(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            persisted: persisted,
            incomes: incomes,
            referenceDate: referenceDate
        )
    }

    func markPaid(
        _ occurrence: BillOccurrence,
        amount: Decimal? = nil,
        date: Date? = nil,
        confirmationNumber: String? = nil,
        source: PaymentEventSource
    ) async throws {
        let remainingBeforePayment = occurrence.bill.remainingBalance(
            for: occurrence.dueDate,
            calendar: calendar
        )
        // Quick-pay (no explicit amount) settles what is still owed, not the
        // full occurrence amount — a swipe on a partially-paid occurrence must
        // not re-record the whole bill on top of the existing partials.
        let paidAmount = amount ?? remainingBeforePayment
        guard paidAmount > 0 else { return }
        let datePaid = date ?? currentDate()
        Logger.log("Marking paid: \(occurrence.name), occurrence: \(occurrence.dueDate), amount: \(paidAmount)", level: .info)
        let recorder = PaymentRecorder()

        _ = try await recorder.recordPayment(
            for: occurrence.bill,
            occurrenceDate: occurrence.dueDate,
            amount: paidAmount,
            datePaid: datePaid,
            confirmationNumber: confirmationNumber,
            calendar: calendar,
            context: modelContext,
            notificationCoordinator: notificationCoordinator,
            badgeCalculator: badgeCalculator,
            badgeMode: notificationPreferences.badgeMode,
            allBills: bills,
            currentDate: currentDate
        )

        analyticsCapture(.paymentRecorded(
            source: source,
            category: occurrence.categoryIdentifier?.analyticsKey ?? "none",
            currencyCode: occurrence.currencyCode,
            daysFromDue: daysBetween(occurrence.dueDate, and: datePaid),
            isPartial: paidAmount < occurrence.amount,
            hasConfirmationNumber: confirmationNumber?.isEmpty == false
        ))

        try refresh()
        await refreshNotifications()
    }

    /// Whole days from `dueDate` to `paidDate`; negative = paid early.
    private func daysBetween(_ dueDate: Date, and paidDate: Date) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: dueDate),
            to: calendar.startOfDay(for: paidDate)
        ).day ?? 0
    }

    func addBill(_ bill: Bill) async throws {
        Logger.log("Adding bill: \(bill.name)", level: .info)
        modelContext.insert(bill)
        try modelContext.save()

        analyticsCapture(.billCreated(
            category: bill.categoryIdentifier?.analyticsKey ?? "none",
            isRecurring: bill.recurrenceRule != nil,
            recurrencePattern: bill.recurrenceRule?.pattern.rawValue ?? "none",
            currencyCode: bill.currencyCode,
            hasNotes: bill.notes?.isEmpty == false,
            hasProviderURL: bill.providerURL?.isEmpty == false,
            hasAccount: bill.accountIdentifier?.isEmpty == false
        ))

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

        // Only count it as an unmark when payments were actually removed —
        // a no-op call must not inflate the metric.
        if payments.isEmpty == false {
            analyticsCapture(.paymentUnmarked(
                category: occurrence.categoryIdentifier?.analyticsKey ?? "none"
            ))
        }

        // Refresh data first, then recalculate badge with fresh state
        try refresh()
        await refreshNotifications()
    }

    /// Deletes a payment entry and refreshes notifications/badge.
    /// Use this centralized method instead of direct modelContext.delete() to ensure
    /// notifications and badge counts stay in sync.
    func deletePaymentEntry(_ payment: PaymentEntry) async throws {
        Logger.log("Deleting payment entry: \(payment.amount) paid on \(payment.datePaid)", level: .info)

        let categoryKey = payment.issuedOccurrence?.billCategoryRawValue
            .flatMap(CategoryIdentifier.init(rawValue:))?.analyticsKey ?? "none"
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

        analyticsCapture(.paymentDeleted(category: categoryKey))

        try refresh()
        await refreshNotifications()
    }

    func deleteBill(_ bill: Bill) async throws {
        Logger.log("Deleting bill: \(bill.name)", level: .info)

        let event = AnalyticsEvent.billDeleted(
            category: bill.categoryIdentifier?.analyticsKey ?? "none",
            isRecurring: bill.recurrenceRule != nil,
            hadPayments: bill.allPaymentEntries.isEmpty == false
        )

        modelContext.delete(bill)
        try modelContext.save()

        analyticsCapture(event)

        try refresh()
        await refreshNotifications()
    }

    func updateBill(_ bill: Bill, preEditSnapshot: BillSnapshot? = nil) async throws {
        if let preEditSnapshot {
            try issuePastDueOccurrencesIfNeeded(for: bill, preEditSnapshot: preEditSnapshot)
        }
        try modelContext.save()

        analyticsCapture(.billUpdated(
            category: bill.categoryIdentifier?.analyticsKey ?? "none",
            isRecurring: bill.recurrenceRule != nil,
            rescheduled: preEditSnapshot.map { $0.dueDate != bill.dueDate } ?? false
        ))

        try refresh()
        await refreshNotifications()
    }

    // MARK: - Income Management

    func addIncome(_ income: Income) async throws {
        Logger.log("Adding income: \(income.name), amount: \(income.amount)", level: .info)
        modelContext.insert(income)
        try modelContext.save()

        analyticsCapture(.incomeCreated(
            isRecurring: income.recurrenceRule != nil,
            recurrencePattern: income.recurrenceRule?.pattern.rawValue ?? "none",
            currencyCode: income.currencyCode
        ))

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

        let event = AnalyticsEvent.incomeDeleted(isRecurring: income.recurrenceRule != nil)

        modelContext.delete(income)
        try modelContext.save()

        analyticsCapture(event)

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

        analyticsCapture(.incomeUpdated(
            isRecurring: income.recurrenceRule != nil,
            recurrencePattern: income.recurrenceRule?.pattern.rawValue ?? "none",
            currencyCode: income.currencyCode
        ))

        try refresh()
    }

    func skipIncomeOccurrence(_ occurrence: IncomeOccurrence) async throws {
        Logger.log(
            "Skipping income occurrence: \(occurrence.incomeName) on \(occurrence.date)",
            level: .info
        )
        try excludeOccurrences(sharingKeyWith: occurrence)
        analyticsCapture(.incomeOccurrenceSkipped)
        try refresh()
    }

    /// Marks every row sharing the occurrence's key as excluded so the operation
    /// is logically per-key. Without this, a CloudKit duplicate at the same key
    /// would leave the un-skipped twin visible after a refresh.
    private func excludeOccurrences(sharingKeyWith occurrence: IncomeOccurrence) throws {
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
        analyticsCapture(.incomeOccurrenceAmountEdited)
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
        try excludeOccurrences(sharingKeyWith: occurrence)
        analyticsCapture(.incomeOccurrenceDeleted)
        try refresh()
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
