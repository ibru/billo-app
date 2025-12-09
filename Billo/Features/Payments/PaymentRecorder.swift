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
        context: ModelContext,
        notificationCoordinator: NotificationCoordinating,
        badgeCalculator: BadgeCalculating,
        badgeMode: BadgeMode,
        allBills: [Bill],
        currentDate: () -> Date
    ) async throws -> Payment {
        Logger.log("Recording payment: \(amount) for \(bill.name)", level: .debug)
        // 1. Create and persist payment
        let payment = Payment(
            amount: amount,
            datePaid: datePaid,
            occurrenceDate: occurrenceDate,
            confirmationNumber: confirmationNumber,
            bill: bill
        )
        context.insert(payment)
        try context.save()
        Logger.log("Payment saved successfully", level: .info)

        // 2. Cancel reminders for this occurrence
        let occurrenceID = BillOccurrence.OccurrenceID(
            billID: bill.persistentModelID,
            dueDate: occurrenceDate
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
