//  Created by Jiri Urbasek on 12/02/25.

import Foundation
import UserNotifications
import SwiftData
import Observation

@Observable
@MainActor
final class NotificationCoordinator: NotificationCoordinating {
    private struct NotificationOccurrenceSnapshot: Sendable {
        let billIDString: String
        let name: String
        let amount: Decimal
        let currencyCode: String
        let dueDate: Date
    }

    // MARK: - Dependencies (all injected)

    private let notificationCenter: UNNotificationCenterProtocol
    private let preferences: NotificationPreferencesReading
    private let occurrenceProvider: BillOccurrenceProviding
    private let dateCalculator: NotificationDateCalculator
    private let contentBuilder: NotificationContentBuilder
    private let badgeCalculator: BadgeCalculator
    private let calendar: Calendar
    private let currentDate: () -> Date

    // MARK: - Configuration

    private let maxNotifications = 64
    private let reservedSlots = 4  // 1 digest + 3 buffer
    private let baseHorizonDays = 90
    private let minHorizonDays = 14  // Never shrink below 2 weeks

    // MARK: - Init

    init(
        notificationCenter: UNNotificationCenterProtocol,
        preferences: NotificationPreferencesReading,
        occurrenceProvider: BillOccurrenceProviding = BillOccurrenceProvider(),
        dateCalculator: NotificationDateCalculator = NotificationDateCalculator(),
        contentBuilder: NotificationContentBuilder = NotificationContentBuilder(),
        calendar: Calendar = .current,
        currentDate: @escaping () -> Date = { Date() }
    ) {
        self.notificationCenter = notificationCenter
        self.preferences = preferences
        self.occurrenceProvider = occurrenceProvider
        self.dateCalculator = dateCalculator
        self.contentBuilder = contentBuilder
        self.badgeCalculator = BadgeCalculator(calendar: calendar, baseHorizonDays: 90)
        self.calendar = calendar
        self.currentDate = currentDate
    }

    // MARK: - Permission

    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await notificationCenter.authorizationStatus()
    }

    func requestAuthorization() async throws -> Bool {
        try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
    }

    // MARK: - Refresh All

    func refreshAllNotifications(for bills: [Bill]) async throws {
        Logger.log("Refreshing all notifications", level: .debug)
        let referenceDate = currentDate()

        // 1. Check permission first - if not authorized, clear everything and return
        let status = await currentAuthorizationStatus()
        Logger.log("Notification permission: \(status.rawValue)", level: .debug)
        guard status == .authorized else {
            await clearBadge()
            await cancelDigest()
            await cancelAllBillReminders()
            return
        }

        // 2. Calculate occurrences for reminders, digest, and badge (using full horizon)
        let allOccurrences = await occurrenceProvider.unpaidOccurrences(
            from: bills,
            referenceDate: referenceDate,
            horizonDays: baseHorizonDays,
            calendar: calendar
        )

        // 3. Handle bill reminders (independent of digest)
        await cancelAllBillReminders()

        if preferences.remindersEnabled {
            // Calculate effective horizon (shrink if cap would be exceeded)
            let effectiveHorizon = calculateEffectiveHorizon(
                allOccurrences: allOccurrences,
                referenceDate: referenceDate
            )
            Logger.log("Effective horizon: \(effectiveHorizon) days", level: .debug)

            // Filter locally instead of re-querying SwiftData models.
            // Note: allOccurrences already includes overdue occurrences within lookback window.
            let schedulingOccurrences: [BillOccurrence]
            if let horizonDate = calendar.date(byAdding: .day, value: effectiveHorizon, to: referenceDate) {
                schedulingOccurrences = allOccurrences.filter { $0.dueDate <= horizonDate }
            } else {
                schedulingOccurrences = allOccurrences
            }

            // Schedule within cap
            let scheduled = try await scheduleRemindersInternal(
                for: schedulingOccurrences,
                referenceDate: referenceDate
            )

            // Log horizon adjustment or cap status
            if effectiveHorizon < baseHorizonDays {
                print("[Notifications] Horizon reduced to \(effectiveHorizon) days to fit cap")
            }
            let (_, skipped) = dateCalculator.schedulingPlan(
                occurrences: schedulingOccurrences,
                offsets: preferences.reminderOffsets,
                maxSlots: maxNotifications - reservedSlots
            )
            if skipped > 0 {
                print("[Notifications] Cap reached: scheduled \(scheduled), skipped \(skipped)")
            }
        }

        // 4. Handle daily digest (independent of reminders)
        if preferences.digestEnabled {
            try await scheduleDigestIfNeeded(
                occurrences: allOccurrences,
                referenceDate: referenceDate
            )
        } else {
            await cancelDigest()
        }

        // 5. Update badge using user-selected badge window (independent of reminders/digest)
        let badgeCount = badgeCalculator.calculateBadgeCount(
            occurrences: allOccurrences,
            badgeMode: preferences.badgeMode,
            referenceDate: referenceDate
        )

        if badgeCount == 0 {
            await clearBadge()
        } else {
            await updateBadge(unpaidCount: badgeCount)
        }
    }

    /// Calculates horizon that fits within notification cap
    /// Shrinks from baseHorizonDays down to minHorizonDays if needed
    private func calculateEffectiveHorizon(
        allOccurrences: [BillOccurrence],
        referenceDate: Date
    ) -> Int {
        let availableSlots = maxNotifications - reservedSlots
        let offsetCount = preferences.reminderOffsets.count

        if offsetCount == 0 {
            return baseHorizonDays
        }

        // Try progressively shorter horizons
        for horizon in stride(from: baseHorizonDays, through: minHorizonDays, by: -7) {
            guard let horizonDate = calendar.date(byAdding: .day, value: horizon, to: referenceDate) else {
                continue
            }

            let count = allOccurrences.filter { $0.dueDate <= horizonDate }.count
            let requiredSlots = count * offsetCount

            if requiredSlots <= availableSlots {
                return horizon
            }
        }

        // Even minHorizonDays exceeds cap - use it anyway, cap will truncate
        return minHorizonDays
    }

    /// Schedules digest, handling mixed currencies gracefully
    private func scheduleDigestIfNeeded(
        occurrences: [BillOccurrence],
        referenceDate: Date
    ) async throws {
        let dueWithinLookahead = dateCalculator.occurrencesWithinLookahead(
            occurrences,
            lookaheadDays: preferences.digestLookaheadDays,
            referenceDate: referenceDate,
            calendar: calendar
        )
        .sorted { $0.dueDate < $1.dueDate }

        guard !dueWithinLookahead.isEmpty else { return }

        let items = dueWithinLookahead.map { NotificationContentBuilder.NotificationDigestItem($0) }
        try await scheduleDigest(
            items: items,
            lookaheadDays: preferences.digestLookaheadDays
        )
    }

    // MARK: - Internal Scheduling

    private func scheduleRemindersInternal(
        for occurrences: [BillOccurrence],
        referenceDate: Date
    ) async throws -> Int {
        let availableSlots = maxNotifications - reservedSlots
        let offsets = preferences.reminderOffsets
        let reminderTime = preferences.reminderTime
        let calendar = calendar
        let dateCalculator = dateCalculator

        let snapshots: [NotificationOccurrenceSnapshot] = occurrences.map {
            NotificationOccurrenceSnapshot(
                billIDString: String(describing: $0.bill.persistentModelID),
                name: $0.name,
                amount: $0.amount,
                currencyCode: $0.currencyCode,
                dueDate: $0.dueDate
            )
        }

        let plan = await Task.detached(priority: .userInitiated) { () -> [(NotificationOccurrenceSnapshot, Int, Date)] in
            var scheduled: [(NotificationOccurrenceSnapshot, Int, Date)] = []

            for snapshot in snapshots {
                guard scheduled.count < availableSlots else { break }

                for offset in offsets {
                    guard scheduled.count < availableSlots else { break }
                    guard let notificationDate = dateCalculator.notificationDate(
                        for: snapshot.dueDate,
                        offsetDays: offset,
                        time: reminderTime,
                        referenceDate: referenceDate,
                        calendar: calendar
                    ) else { continue }

                    scheduled.append((snapshot, offset, notificationDate))
                }
            }

            return scheduled
        }.value

        // Log notification schedule
        logNotificationSchedule(plan: plan, availableSlots: availableSlots)

        for (snapshot, offset, notificationDate) in plan {
            let request = createNotificationRequest(
                snapshot: snapshot,
                notificationDate: notificationDate,
                offsetDays: offset
            )
            try await notificationCenter.add(request)
        }

        return plan.count
    }

    private func createNotificationRequest(
        snapshot: NotificationOccurrenceSnapshot,
        notificationDate: Date,
        offsetDays: Int
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = snapshot.name
        content.body = contentBuilder.reminderBody(
            amount: snapshot.amount,
            currencyCode: snapshot.currencyCode,
            offsetDays: offsetDays
        )
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.billReminder
        content.userInfo = [
            "billID": snapshot.billIDString,
            "occurrenceTimestamp": snapshot.dueDate.timeIntervalSinceReferenceDate,
            "offsetDays": offsetDays
        ]

        let billIDHash = NotificationIdentifier.shortHash(
            of: snapshot.billIDString
        )
        let identifier = NotificationIdentifier(
            billIDHash: billIDHash,
            occurrenceTimestamp: Int(snapshot.dueDate.timeIntervalSinceReferenceDate),
            offsetDays: offsetDays
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: notificationDate
            ),
            repeats: false
        )

        return UNNotificationRequest(
            identifier: identifier.stringValue,
            content: content,
            trigger: trigger
        )
    }

    // MARK: - Cancellation

    private func cancelAllBillReminders() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let billReminderIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("billo.r.") }

        if !billReminderIDs.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: billReminderIDs)
        }
    }

    func cancelReminders(for occurrenceIDs: [BillOccurrence.OccurrenceID]) async {
        let pending = await notificationCenter.pendingNotificationRequests()

        var idsToCancel: [String] = []

        for pendingRequest in pending {
            guard let parsed = NotificationIdentifier.parse(pendingRequest.identifier) else { continue }

            for occurrenceID in occurrenceIDs {
                let billIDHash = NotificationIdentifier.shortHash(
                    of: String(describing: occurrenceID.billID)
                )
                let occurrenceTimestamp = Int(occurrenceID.dueTime)

                if parsed.billIDHash == billIDHash &&
                   parsed.occurrenceTimestamp == occurrenceTimestamp {
                    idsToCancel.append(pendingRequest.identifier)
                }
            }
        }

        if !idsToCancel.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: idsToCancel)
        }
    }

    func cancelAllReminders(forBillID billID: String) async {
        let hash = NotificationIdentifier.shortHash(of: billID)
        let prefix = NotificationIdentifier.prefix(forBillIDHash: hash)
        let pending = await notificationCenter.pendingNotificationRequests()
        let idsToCancel = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }

        if !idsToCancel.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: idsToCancel)
        }
    }

    func rescheduleReminders(
        forBillID billID: String,
        newOccurrences: [BillOccurrence]
    ) async throws {
        await cancelAllReminders(forBillID: billID)

        guard preferences.remindersEnabled else { return }

        _ = try await scheduleRemindersInternal(
            for: newOccurrences,
            referenceDate: currentDate()
        )
    }

    // MARK: - Digest

    func scheduleDigest(
        items: [NotificationContentBuilder.NotificationDigestItem],
        lookaheadDays: Int
    ) async throws {
        await cancelDigest()

        let content = UNMutableNotificationContent()
        content.title = contentBuilder.digestTitle(
            billCount: items.count,
            lookaheadDays: lookaheadDays
        )
        content.body = contentBuilder.digestBody(items: items, maxLines: 5)
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.dailyDigest

        let digestTime = preferences.digestTime
        var components = DateComponents()
        components.hour = digestTime.hour ?? 9
        components.minute = digestTime.minute ?? 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.digestIdentifier,
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
    }

    func cancelDigest() async {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [NotificationIdentifier.digestIdentifier]
        )
    }

    // MARK: - Badge

    func updateBadge(unpaidCount: Int) async {
        guard case .never = preferences.badgeMode else {
            try? await notificationCenter.setBadgeCount(unpaidCount)
            return
        }
        // If badgeMode is .never, always clear
        await clearBadge()
    }

    func clearBadge() async {
        try? await notificationCenter.setBadgeCount(0)
    }

    // MARK: - Public scheduling

    func scheduleReminders(for occurrences: [BillOccurrence]) async throws {
        guard preferences.remindersEnabled else { return }
        _ = try await scheduleRemindersInternal(for: occurrences, referenceDate: currentDate())
    }

    // MARK: - Logging

    private func logNotificationSchedule(
        plan: [(NotificationOccurrenceSnapshot, Int, Date)],
        availableSlots: Int
    ) {
        Logger.log("=== NOTIFICATION SCHEDULE ===", level: .info)
        Logger.log("Total scheduled: \(plan.count), Remaining capacity: \(availableSlots - plan.count)", level: .info)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        for (index, (snapshot, offset, notificationDate)) in plan.prefix(5).enumerated() {
            let dateStr = formatter.string(from: notificationDate)
            let body = contentBuilder.reminderBody(
                amount: snapshot.amount,
                currencyCode: snapshot.currencyCode,
                offsetDays: offset
            )
            Logger.log("[\(index + 1)] \(dateStr) - \(snapshot.name): \(body)", level: .info)
        }

        if plan.count > 5 {
            Logger.log("... and \(plan.count - 5) more notifications", level: .info)
        }
        Logger.log("=============================", level: .info)
    }
}
