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

    private struct ScheduledReminderKey: Hashable, Sendable {
        let billIDString: String
        let occurrenceTimestamp: Int
    }

    private struct ReminderPlan: Sendable {
        let plan: [(NotificationOccurrenceSnapshot, Int, Date)]
        let scheduledOccurrences: Set<ScheduledReminderKey>
    }

    private struct DigestCandidate {
        let notificationDate: Date
        let upcomingOccurrences: [BillOccurrence]
        let overdueOccurrences: [BillOccurrence]
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
    private let baseHorizonDays = 90
    private let minHorizonDays = 14  // Never shrink below 2 weeks
    private let digestWindowDaysWithReminders = 14

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
        Logger.log("Preferences - reminders: \(preferences.remindersEnabled), digest: \(preferences.digestEnabled), lookahead: \(preferences.digestLookaheadDays)", level: .debug)
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

        // 3. Cancel all pending reminders/digests before rescheduling
        await cancelAllBillReminders()
        await cancelDigest()

        // 4. Plan reminders and rolling digest together (suppression avoids duplicates)
        let digestCandidates = makeDigestCandidates(
            occurrences: allOccurrences,
            referenceDate: referenceDate
        )
        Logger.log("Created \(digestCandidates.count) digest candidates", level: .debug)

        let plans = await computeNotificationPlans(
            occurrences: allOccurrences,
            referenceDate: referenceDate,
            digestCandidates: digestCandidates
        )
        Logger.log("After suppression: \(plans.digestPlan.count) digests will be scheduled", level: .debug)

        if preferences.remindersEnabled {
            try await scheduleReminderPlan(plans.reminderPlan)
        }

        if preferences.digestEnabled {
            Logger.log("Digest enabled: scheduling \(plans.digestPlan.count) digests", level: .info)
            for candidate in plans.digestPlan {
                let upcomingItems = candidate.upcomingOccurrences
                    .map { NotificationContentBuilder.NotificationDigestItem($0) }
                let overdueItems = candidate.overdueOccurrences
                    .map { NotificationContentBuilder.NotificationDigestItem($0) }
                let identifier = NotificationIdentifier.digestIdentifier(
                    for: candidate.notificationDate,
                    calendar: calendar
                )
                try await scheduleDigest(
                    upcomingItems: upcomingItems,
                    overdueItems: overdueItems,
                    lookaheadDays: preferences.digestLookaheadDays,
                    notificationDate: candidate.notificationDate,
                    identifier: identifier
                )
            }
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
        referenceDate: Date,
        availableSlots: Int
    ) -> Int {
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

    private func makeDigestCandidates(
        occurrences: [BillOccurrence],
        referenceDate: Date
    ) -> [DigestCandidate] {
        guard preferences.digestEnabled else {
            Logger.log("Digest disabled in preferences", level: .debug)
            return []
        }

        let startOfReference = calendar.startOfDay(for: referenceDate)
        let windowDays = preferences.remindersEnabled ? digestWindowDaysWithReminders : maxNotifications
        let digestTime = preferences.digestTime
        Logger.log("Making digest candidates: windowDays=\(windowDays), lookahead=\(preferences.digestLookaheadDays)", level: .debug)

        return (0..<windowDays).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfReference) else {
                return nil
            }

            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = digestTime.hour ?? 9
            components.minute = digestTime.minute ?? 0

            guard let notificationDate = calendar.date(from: components) else {
                return nil
            }

            guard notificationDate > referenceDate else {
                return nil
            }

            let upcoming = dateCalculator.occurrencesWithinLookahead(
                occurrences,
                lookaheadDays: preferences.digestLookaheadDays,
                referenceDate: day,
                calendar: calendar
            )
            .sorted { $0.dueDate < $1.dueDate }

            let overdue = occurrences
                .filter { calendar.startOfDay(for: $0.dueDate) < day }
                .sorted { $0.dueDate > $1.dueDate }

            guard upcoming.isEmpty == false || overdue.isEmpty == false else {
                return nil
            }

            let candidate = DigestCandidate(
                notificationDate: notificationDate,
                upcomingOccurrences: upcoming,
                overdueOccurrences: overdue
            )
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            Logger.log("Digest candidate: \(formatter.string(from: notificationDate)) - \(upcoming.count) upcoming, \(overdue.count) overdue", level: .debug)
            return candidate
        }
    }

    private func computeNotificationPlans(
        occurrences: [BillOccurrence],
        referenceDate: Date,
        digestCandidates: [DigestCandidate]
    ) async -> (reminderPlan: [(NotificationOccurrenceSnapshot, Int, Date)], digestPlan: [DigestCandidate]) {
        let digestCandidates = preferences.digestEnabled ? digestCandidates : []
        guard preferences.remindersEnabled else {
            let digestPlan = digestCandidates
            return (reminderPlan: [], digestPlan: digestPlan)
        }

        var digestPlan = digestCandidates
        var digestCount = digestPlan.count
        var previousDigestCount = -1
        var reminderPlan: [(NotificationOccurrenceSnapshot, Int, Date)] = []
        var scheduledReminders = Set<ScheduledReminderKey>()

        let maxIterations = max(1, digestCandidates.count + 1)
        var iterations = 0

        while digestCount != previousDigestCount && iterations < maxIterations {
            previousDigestCount = digestCount

            let availableSlots = max(0, maxNotifications - digestCount)
            let plan = await planReminders(
                occurrences: occurrences,
                referenceDate: referenceDate,
                availableSlots: availableSlots
            )
            reminderPlan = plan.plan
            scheduledReminders = plan.scheduledOccurrences

            digestPlan = digestCandidates.filter {
                shouldSuppressDigest(candidate: $0, scheduledReminders: scheduledReminders) == false
            }
            digestCount = digestPlan.count
            iterations += 1
        }

        return (reminderPlan: reminderPlan, digestPlan: digestPlan)
    }

    private func shouldSuppressDigest(
        candidate: DigestCandidate,
        scheduledReminders: Set<ScheduledReminderKey>
    ) -> Bool {
        guard preferences.remindersEnabled else { return false }
        let totalOccurrences = candidate.upcomingOccurrences + candidate.overdueOccurrences
        guard totalOccurrences.count == 1 else {
            Logger.log("Digest with \(totalOccurrences.count) occurrences NOT suppressed", level: .debug)
            return false
        }
        let occurrence = totalOccurrences[0]

        let key = ScheduledReminderKey(
            billIDString: occurrence.bill.stableID,
            occurrenceTimestamp: occurrenceTimestamp(for: occurrence.dueDate)
        )

        let suppressed = scheduledReminders.contains(key)
        if suppressed {
            Logger.log("Digest for '\(occurrence.name)' suppressed (has reminder)", level: .debug)
        }
        return suppressed
    }

    // MARK: - Internal Scheduling

    private func planReminders(
        occurrences: [BillOccurrence],
        referenceDate: Date,
        availableSlots: Int
    ) async -> ReminderPlan {
        guard availableSlots > 0 else {
            return ReminderPlan(plan: [], scheduledOccurrences: [])
        }

        let offsets = preferences.reminderOffsets
        guard offsets.isEmpty == false else {
            return ReminderPlan(plan: [], scheduledOccurrences: [])
        }

        // Calculate effective horizon (shrink if cap would be exceeded)
        let effectiveHorizon = calculateEffectiveHorizon(
            allOccurrences: occurrences,
            referenceDate: referenceDate,
            availableSlots: availableSlots
        )
        Logger.log("Effective horizon: \(effectiveHorizon) days", level: .debug)

        // Filter locally instead of re-querying SwiftData models.
        // Note: occurrences already includes overdue occurrences within lookback window.
        let schedulingOccurrences: [BillOccurrence]
        if let horizonDate = calendar.date(byAdding: .day, value: effectiveHorizon, to: referenceDate) {
            schedulingOccurrences = occurrences.filter { $0.dueDate <= horizonDate }
        } else {
            schedulingOccurrences = occurrences
        }

        let reminderTime = preferences.reminderTime
        let calendar = calendar
        let dateCalculator = dateCalculator

        let snapshots: [NotificationOccurrenceSnapshot] = schedulingOccurrences.map {
            NotificationOccurrenceSnapshot(
                billIDString: $0.bill.stableID,
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

        let scheduledKeys = Set(
            plan.map {
                ScheduledReminderKey(
                    billIDString: $0.0.billIDString,
                    occurrenceTimestamp: occurrenceTimestamp(for: $0.0.dueDate)
                )
            }
        )

        // Log horizon adjustment or cap status
        if effectiveHorizon < baseHorizonDays {
            Logger.log("Horizon reduced to \(effectiveHorizon) days to fit cap", level: .info)
        }
        let (_, skipped) = dateCalculator.schedulingPlan(
            occurrences: schedulingOccurrences,
            offsets: offsets,
            maxSlots: availableSlots
        )
        if skipped > 0 {
            Logger.log("Cap reached: scheduled \(plan.count), skipped \(skipped)", level: .info)
        }

        return ReminderPlan(
            plan: plan,
            scheduledOccurrences: scheduledKeys
        )
    }

    private func scheduleReminderPlan(
        _ plan: [(NotificationOccurrenceSnapshot, Int, Date)]
    ) async throws {
        for (snapshot, offset, notificationDate) in plan {
            let request = createNotificationRequest(
                snapshot: snapshot,
                notificationDate: notificationDate,
                offsetDays: offset
            )
            try await notificationCenter.add(request)
        }
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

        let normalizedDueDate = normalizedOccurrenceDate(for: snapshot.dueDate)
        content.userInfo = [
            "billID": snapshot.billIDString,
            "occurrenceTimestamp": normalizedDueDate.timeIntervalSinceReferenceDate,
            "offsetDays": offsetDays
        ]

        let billIDHash = NotificationIdentifier.shortHash(
            of: snapshot.billIDString
        )
        let identifier = NotificationIdentifier(
            billIDHash: billIDHash,
            occurrenceTimestamp: occurrenceTimestamp(for: snapshot.dueDate),
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

    private func normalizedOccurrenceDate(for dueDate: Date) -> Date {
        calendar.startOfDay(for: dueDate)
    }

    private func occurrenceTimestamp(for dueDate: Date) -> Int {
        Int(normalizedOccurrenceDate(for: dueDate).timeIntervalSinceReferenceDate)
    }

    func cancelReminders(for occurrenceIDs: [BillOccurrence.OccurrenceID]) async {
        let pending = await notificationCenter.pendingNotificationRequests()

        var idsToCancel: [String] = []

        for pendingRequest in pending {
            guard let parsed = NotificationIdentifier.parse(pendingRequest.identifier) else { continue }

            for occurrenceID in occurrenceIDs {
                let billIDHash = NotificationIdentifier.shortHash(
                    of: occurrenceID.billID
                )
                let rawDate = Date(timeIntervalSinceReferenceDate: occurrenceID.dueTime)
                let occurrenceTimestamp = occurrenceTimestamp(for: rawDate)

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

        let plan = await planReminders(
            occurrences: newOccurrences,
            referenceDate: currentDate(),
            availableSlots: maxNotifications
        )
        try await scheduleReminderPlan(plan.plan)
    }

    // MARK: - Digest

    func scheduleDigest(
        upcomingItems: [NotificationContentBuilder.NotificationDigestItem],
        overdueItems: [NotificationContentBuilder.NotificationDigestItem],
        lookaheadDays: Int,
        notificationDate: Date,
        identifier: String
    ) async throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        Logger.log("Scheduling digest: \(formatter.string(from: notificationDate)) - \(upcomingItems.count) upcoming, \(overdueItems.count) overdue", level: .info)

        let content = UNMutableNotificationContent()
        content.title = contentBuilder.digestTitle(
            upcomingCount: upcomingItems.count,
            lookaheadDays: lookaheadDays,
            overdueCount: overdueItems.count
        )
        content.body = contentBuilder.digestBody(
            upcomingItems: upcomingItems,
            overdueItems: overdueItems,
            maxLines: 5
        )
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.dailyDigest

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: notificationDate
            ),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
    }

    func cancelDigest() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let digestIDs = pending
            .map(\.identifier)
            .filter { NotificationIdentifier.isDigestIdentifier($0) }

        if digestIDs.isEmpty == false {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: digestIDs)
        }
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
        let plan = await planReminders(
            occurrences: occurrences,
            referenceDate: currentDate(),
            availableSlots: maxNotifications
        )
        try await scheduleReminderPlan(plan.plan)
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
