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
        // Fetch both bills and incomes from same context for data consistency
        let billDescriptor = FetchDescriptor<Bill>(sortBy: [SortDescriptor(\.dueDate)])
        bills = try modelContext.fetch(billDescriptor)

        let incomeDescriptor = FetchDescriptor<Income>(sortBy: [SortDescriptor(\.startDate)])
        incomes = try modelContext.fetch(incomeDescriptor)

        sections = BillsListSections.build(
            from: bills,
            incomes: incomes,
            referenceDate: currentDate(),
            calendar: calendar,
            monthsAhead: monthsAhead
        )
        Logger.log("Refreshed bills: \(bills.count), incomes: \(incomes.count), months: \(monthsAhead)", level: .debug)
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
        modelContext.delete(income)
        try modelContext.save()
        try refresh()
    }

    func updateIncome(_ income: Income) async throws {
        income.lastUpdatedDate = currentDate()
        try modelContext.save()
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

            let key = preEditSnapshot.occurrenceKey(for: dueDate, calendar: calendar)
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

// MARK: - Protocol Conformance

extension BillsModel: BillsRefreshing { }
