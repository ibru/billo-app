//  Created by Jiri Urbasek on 12/02/25.

import Foundation
import SwiftData

enum NotificationActionError: LocalizedError {
    case billNotFound
    case invalidIdentifier
    case paymentFailed(Error)

    var errorDescription: String? {
        switch self {
        case .billNotFound:
            return "Bill no longer exists"
        case .invalidIdentifier:
            return "Invalid notification"
        case .paymentFailed(let error):
            return "Payment failed: \(error.localizedDescription)"
        }
    }
}

struct NotificationActionHandler: Sendable {
    private let badgeCalculator: BadgeCalculator

    init(calendar: Calendar = .current) {
        self.badgeCalculator = BadgeCalculator(calendar: calendar, baseHorizonDays: 90)
    }

    /// Handles Mark Paid action. Returns silently if bill/occurrence not found (stale notification).
    @MainActor
    func handleMarkPaid(
        notificationIdentifier: String,
        modelContainer: ModelContainer,
        notificationCoordinator: NotificationCoordinating,
        notificationPreferences: NotificationPreferencesReading
    ) async {
        // 1. Parse identifier
        guard let parsed = NotificationIdentifier.parse(notificationIdentifier) else {
            // Stale or invalid notification - ignore silently
            print("[Notifications] Invalid identifier, ignoring: \(notificationIdentifier)")
            return
        }

        // 2. Find bill
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Bill>()

        guard let bills = try? context.fetch(descriptor) else {
            print("[Notifications] Failed to fetch bills")
            return
        }

        let billIDHash = parsed.billIDHash
        var foundBill: Bill?
        for b in bills {
            // Create hash from PersistentIdentifier string representation
            let hash = NotificationIdentifier.shortHash(of: String(describing: b.persistentModelID))
            if hash == billIDHash {
                foundBill = b
                break
            }
        }

        guard let bill = foundBill else {
            // Bill was deleted - graceful no-op
            print("[Notifications] Bill not found (may have been deleted), ignoring")
            return
        }

        // 3. Record payment
        let occurrenceDate = Date(timeIntervalSinceReferenceDate: TimeInterval(parsed.occurrenceTimestamp))

        let recorder = PaymentRecorder()

        do {
            _ = try await recorder.recordPayment(
                for: bill,
                occurrenceDate: occurrenceDate,
                amount: bill.amount,
                datePaid: Date(),
                confirmationNumber: nil,
                context: context,
                notificationCoordinator: notificationCoordinator,
                badgeCalculator: badgeCalculator,
                badgeMode: notificationPreferences.badgeMode,
                allBills: bills,
                currentDate: { Date() }
            )
        } catch {
            print("[Notifications] Failed to record payment: \(error)")
            return
        }
    }
}
