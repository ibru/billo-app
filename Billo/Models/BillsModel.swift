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
        // Fetch both bills and incomes from same context for data consistency
        let billDescriptor = FetchDescriptor<Bill>(sortBy: [SortDescriptor(\.dueDate)])
        bills = try modelContext.fetch(billDescriptor)

        let incomeDescriptor = FetchDescriptor<Income>(sortBy: [SortDescriptor(\.startDate)])
        incomes = try modelContext.fetch(incomeDescriptor)

        sections = BillsListSections.build(
            from: bills,
            incomes: incomes,
            referenceDate: currentDate(),
            calendar: calendar
        )
        Logger.log("Refreshed bills: \(bills.count), incomes: \(incomes.count)", level: .debug)
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
        let payments = occurrence.bill.safePayments.filter { payment in
            calendar.isDate(payment.occurrenceDate, inSameDayAs: occurrence.dueDate)
        }

        for payment in payments {
            modelContext.delete(payment)
        }
        try modelContext.save()

        // Reschedule and update badge
        try? await notificationCoordinator.scheduleReminders(for: [occurrence])
        let unpaidCount = calculateUnpaidCount()
        await notificationCoordinator.updateBadge(unpaidCount: unpaidCount)

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

    func updateBill(_ bill: Bill) async throws {
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
}

// MARK: - Protocol Conformance

extension BillsModel: BillsRefreshing { }
