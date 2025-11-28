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
    @ObservationIgnored private let paymentHistoryRefresher: PaymentHistoryRefreshing?

    private(set) var bills: [Bill] = []
    private(set) var sections: BillsListSections = .empty

    init(
        modelContext: ModelContext,
        calendar: Calendar = .current,
        currentDate: @escaping () -> Date = { Date() },
        paymentHistoryRefresher: PaymentHistoryRefreshing? = nil
    ) {
        self.modelContext = modelContext
        self.calendar = calendar
        self.currentDate = currentDate
        self.paymentHistoryRefresher = paymentHistoryRefresher
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
    ) throws {
        let payment = Payment(
            amount: amount ?? occurrence.amount,
            datePaid: date ?? currentDate(),
            occurrenceDate: occurrence.dueDate,
            confirmationNumber: confirmationNumber,
            bill: occurrence.bill
        )

        modelContext.insert(payment)
        try modelContext.save()

        cancelReminder(for: occurrence)

        try refresh()

        notifyPaymentHistoryRefresh()
    }

    func markUnpaid(_ occurrence: BillOccurrence) throws {
        let payments = occurrence.bill.payments.filter { payment in
            calendar.isDate(payment.occurrenceDate, inSameDayAs: occurrence.dueDate)
        }

        for payment in payments {
            modelContext.delete(payment)
        }

        try modelContext.save()

        rescheduleReminder(for: occurrence)

        try refresh()

        notifyPaymentHistoryReload()
    }

    private func cancelReminder(for occurrence: BillOccurrence) {
        // TODO: Implement notification cancellation when reminder system is added
        // This will use UNUserNotificationCenter to remove pending notifications
        // identified by the occurrence ID
    }

    private func rescheduleReminder(for occurrence: BillOccurrence) {
        // TODO: Implement notification rescheduling when reminder system is added
        // This will recreate the notification for this specific occurrence
        // without affecting other future occurrences
    }

    func deleteBill(_ bill: Bill) throws {
        modelContext.delete(bill)
        try modelContext.save()
        try refresh()
    }

    private func notifyPaymentHistoryRefresh() {
        guard let paymentHistoryRefresher else { return }

        Task { @MainActor in
            do {
                try await paymentHistoryRefresher.refresh()
            } catch {
                print("Payment history refresh failed: \(error)")
            }
        }
    }

    private func notifyPaymentHistoryReload() {
        guard let paymentHistoryRefresher else { return }

        Task { @MainActor in
            do {
                try await paymentHistoryRefresher.reloadVisibleWindow()
            } catch {
                print("Payment history reload failed: \(error)")
            }
        }
    }
}
