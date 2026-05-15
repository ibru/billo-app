//  Created by Jiri Urbasek on 12/03/25.

import Foundation
import SwiftData

/// Records payment for a bill occurrence and coordinates notification cleanup
struct PaymentRecorder: Sendable {
    @MainActor
    func recordPayment(
        for bill: Bill,
        occurrenceDate: Date,
        amount: Decimal,
        datePaid: Date,
        confirmationNumber: String?,
        calendar: Calendar = .current,
        context: ModelContext,
        notificationCoordinator: NotificationCoordinating,
        badgeCalculator: BadgeCalculating,
        badgeMode: BadgeMode,
        allBills: [Bill],
        currentDate: () -> Date
    ) async throws -> PaymentEntry {
        Logger.log("Recording payment: \(amount) for \(bill.name)", level: .debug)
        let normalizedOccurrenceDate = calendar.startOfDay(for: occurrenceDate)
        let issuedOccurrence: IssuedOccurrence
        if let existingIssued = bill.issuedOccurrence(for: normalizedOccurrenceDate, calendar: calendar) {
            issuedOccurrence = existingIssued
        } else {
            let key = bill.occurrenceKey(for: normalizedOccurrenceDate)
            let issued = IssuedOccurrence(
                occurrenceKey: key,
                dueDate: normalizedOccurrenceDate,
                billName: bill.name,
                billAmount: bill.amount,
                billCurrencyCode: bill.currencyCode,
                billAccountIdentifier: bill.accountIdentifier,
                billNotes: bill.notes,
                billCategoryRawValue: bill.categoryIdentifier?.rawValue,
                bill: bill
            )
            context.insert(issued)
            issuedOccurrence = issued
        }

        // 1. Create and persist payment entry
        let payment = PaymentEntry(
            amount: amount,
            datePaid: datePaid,
            confirmationNumber: confirmationNumber,
            issuedOccurrence: issuedOccurrence
        )
        context.insert(payment)
        try context.save()
        Logger.log("Payment saved successfully", level: .info)

        // 2. Cancel reminders for this occurrence
        let occurrenceID = BillOccurrence.OccurrenceID(
            billID: bill.stableID,
            dueDate: normalizedOccurrenceDate
        )
        await notificationCoordinator.cancelReminders(for: [occurrenceID])

        // 3. Update badge count
        let unpaidCount = badgeCalculator.calculateBadgeCount(
            bills: allBills,
            badgeMode: badgeMode,
            referenceDate: currentDate()
        )
        await notificationCoordinator.updateBadge(unpaidCount: unpaidCount)

        return payment
    }
}
