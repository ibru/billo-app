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
            return String(localized: "Bill no longer exists")
        case .invalidIdentifier:
            return String(localized: "Invalid notification")
        case .paymentFailed(let error):
            return String(localized: "Payment failed: \(error.localizedDescription)")
        }
    }
}

struct NotificationActionHandler: Sendable {
    private let calendar: Calendar
    private let badgeCalculator: BadgeCalculator

    init(calendar: Calendar = .current) {
        self.calendar = calendar
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
            Logger.log("Invalid identifier, ignoring: \(notificationIdentifier)", level: .warning)
            return
        }

        // 2. Find bill
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Bill>()

        guard let bills = try? context.fetch(descriptor) else {
            Logger.log("Failed to fetch bills", level: .error)
            return
        }

        let billIDHash = parsed.billIDHash
        var foundBill: Bill?
        for b in bills {
            let hash = NotificationIdentifier.shortHash(of: b.stableID)
            if hash == billIDHash {
                foundBill = b
                break
            }
        }

        guard let bill = foundBill else {
            // Bill was deleted - graceful no-op
            Logger.log("Bill not found (may have been deleted), ignoring", level: .info)
            return
        }

        // 3. Record payment
        let occurrenceDate = Date(timeIntervalSinceReferenceDate: TimeInterval(parsed.occurrenceTimestamp))
        let expectedAmount = bill.expectedAmount(for: occurrenceDate, calendar: calendar)

        let recorder = PaymentRecorder()

        do {
            _ = try await recorder.recordPayment(
                for: bill,
                occurrenceDate: occurrenceDate,
                amount: expectedAmount,
                datePaid: Date(),
                confirmationNumber: nil,
                calendar: calendar,
                context: context,
                notificationCoordinator: notificationCoordinator,
                badgeCalculator: badgeCalculator,
                badgeMode: notificationPreferences.badgeMode,
                allBills: bills,
                currentDate: { Date() }
            )
        } catch {
            Logger.log("Failed to record payment: \(error)", level: .error)
            return
        }
    }
}
