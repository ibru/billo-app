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
    @ObservationIgnored private let paymentHistoryRefresher: PaymentHistoryRefreshing
    @ObservationIgnored private let notificationCoordinator: NotificationCoordinating
    @ObservationIgnored private let notificationPreferences: NotificationPreferencesReading
    @ObservationIgnored private let badgeCalculator: BadgeCalculator

    private(set) var bills: [Bill] = []
    private(set) var sections: BillsListSections = .empty

    init(
        modelContext: ModelContext,
        calendar: Calendar = .current,
        currentDate: @escaping () -> Date = { Date() },
        paymentHistoryRefresher: PaymentHistoryRefreshing,
        notificationCoordinator: NotificationCoordinating,
        notificationPreferences: NotificationPreferencesReading
    ) {
        self.modelContext = modelContext
        self.calendar = calendar
        self.currentDate = currentDate
        self.paymentHistoryRefresher = paymentHistoryRefresher
        self.notificationCoordinator = notificationCoordinator
        self.notificationPreferences = notificationPreferences
        self.badgeCalculator = BadgeCalculator(calendar: calendar, baseHorizonDays: 90)
    }

    func refresh() throws {
        let descriptor = FetchDescriptor<Bill>(sortBy: [SortDescriptor(\.dueDate)])
        bills = try modelContext.fetch(descriptor)
        sections = BillsListSections.build(
            from: bills,
            referenceDate: currentDate(),
            calendar: calendar
        )
    }

    func markPaid(
        _ occurrence: BillOccurrence,
        amount: Decimal? = nil,
        date: Date? = nil,
        confirmationNumber: String? = nil
    ) async throws {
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
        try await paymentHistoryRefresher.refresh()
    }

    func markUnpaid(_ occurrence: BillOccurrence) async throws {
        let payments = occurrence.bill.payments.filter { payment in
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
        try await paymentHistoryRefresher.reloadVisibleWindow()
    }

    func deleteBill(_ bill: Bill) async throws {
        // Cancel notifications BEFORE deleting
        let billID = String(describing: bill.persistentModelID)
        await notificationCoordinator.cancelAllReminders(forBillID: billID)

        modelContext.delete(bill)
        try modelContext.save()
        try refresh()

        let unpaidCount = calculateUnpaidCount()
        await notificationCoordinator.updateBadge(unpaidCount: unpaidCount)
    }

    func updateBill(_ bill: Bill) async throws {
        try modelContext.save()
        try refresh()

        // Reschedule notifications for this bill
        guard let horizonEnd = calendar.date(byAdding: .day, value: 90, to: currentDate()) else {
            return
        }

        // Use unpaidOccurrences(aroundDate:) which includes appropriate lookback window
        // Then filter to the horizon to avoid scheduling far-future occurrences
        let unpaidDates = bill.unpaidOccurrences(
            aroundDate: currentDate(),
            calendar: calendar
        )
        .filter { $0 <= horizonEnd }  // Keep occurrences within horizon (includes overdue)

        let newOccurrences = unpaidDates.map { BillOccurrence(bill: bill, dueDate: $0) }

        let billID = String(describing: bill.persistentModelID)
        try? await notificationCoordinator.rescheduleReminders(
            forBillID: billID,
            newOccurrences: newOccurrences
        )
    }

    private func calculateUnpaidCount() -> Int {
        // Use BadgeCalculator to respect user's badge window preference
        return badgeCalculator.calculateBadgeCount(
            bills: bills,
            badgeMode: notificationPreferences.badgeMode,
            referenceDate: currentDate()
        )
    }
}
