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
    private let currentDate: @Sendable () -> Date

    init(calendar: Calendar = .current, currentDate: @escaping @Sendable () -> Date = { Date() }) {
        self.calendar = calendar
        self.currentDate = currentDate
        self.badgeCalculator = BadgeCalculator(calendar: calendar, baseHorizonDays: 90)
    }

    /// Handles Mark Paid action. Returns silently if bill/occurrence not found (stale notification).
    ///
    /// `isPro` drives the free-tier display cap: recording the payment always
    /// targets the found bill (full payments are free-tier legal, even on a
    /// hidden bill), but badge/reminder state must derive from the *visible*
    /// bill set only — a stale action can fire without the app ever opening,
    /// so this is the only place that keeps the cap honest in the background.
    @MainActor
    func handleMarkPaid(
        notificationIdentifier: String,
        modelContainer: ModelContainer,
        notificationCoordinator: NotificationCoordinating,
        notificationPreferences: NotificationPreferencesReading,
        isPro: Bool = true,
        analyticsCapture: (@MainActor (AnalyticsEvent) -> Void)? = nil
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
            let datePaid = currentDate()
            let visibleBills = BillsModel.visibleBills(
                from: bills,
                isPro: isPro,
                referenceDate: datePaid,
                calendar: calendar
            )
            _ = try await recorder.recordPayment(
                for: bill,
                occurrenceDate: occurrenceDate,
                amount: expectedAmount,
                datePaid: datePaid,
                confirmationNumber: nil,
                calendar: calendar,
                context: context,
                notificationCoordinator: notificationCoordinator,
                badgeCalculator: badgeCalculator,
                badgeMode: notificationPreferences.badgeMode,
                allBills: visibleBills,
                currentDate: currentDate
            )

            // Paying a bill can change the visible-set ranking (the paid bill
            // drops back; a hidden bill may earn a slot), and the recorder
            // only cancels/badges — it never reschedules. One full refresh
            // from the post-payment visible set keeps reminders, digest, and
            // badge consistent even when the app never comes to foreground.
            // Own do/catch: a notification failure must not read as a payment
            // failure or swallow the analytics capture — the payment is saved.
            do {
                let visibleAfterPayment = BillsModel.visibleBills(
                    from: bills,
                    isPro: isPro,
                    referenceDate: currentDate(),
                    calendar: calendar
                )
                try await notificationCoordinator.refreshAllNotifications(for: visibleAfterPayment)
            } catch {
                Logger.log("Failed to refresh notifications after notification-action payment: \(error)", level: .error)
            }

            let daysFromDue = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: occurrenceDate),
                to: calendar.startOfDay(for: datePaid)
            ).day ?? 0
            // Use the occurrence snapshot when one exists so the event's
            // category/currency match what the payment was recorded against,
            // even if the bill was re-categorized after the occurrence issued.
            let snapshot = bill.snapshot(for: occurrenceDate, calendar: calendar)
            analyticsCapture?(.paymentRecorded(
                source: .notificationAction,
                category: (snapshot?.categoryIdentifier ?? bill.categoryIdentifier)?.analyticsKey ?? "none",
                currencyCode: snapshot?.currencyCode ?? bill.currencyCode,
                daysFromDue: daysFromDue,
                isPartial: false,
                hasConfirmationNumber: false
            ))
        } catch {
            Logger.log("Failed to record payment: \(error)", level: .error)
            return
        }
    }
}
