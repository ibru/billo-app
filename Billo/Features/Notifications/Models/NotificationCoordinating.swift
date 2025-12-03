//  Created by Jiri Urbasek on 12/02/25.

import Foundation
import UserNotifications

/// Single protocol for all notification operations
protocol NotificationCoordinating: Sendable {
    // MARK: - Permission

    /// Current authorization status
    func currentAuthorizationStatus() async -> UNAuthorizationStatus

    /// Requests authorization, returns true if granted
    func requestAuthorization() async throws -> Bool

    // MARK: - Scheduling

    /// Refreshes all notifications (called on app foreground)
    func refreshAllNotifications(for bills: [Bill]) async throws

    /// Schedules reminders for specific occurrences
    func scheduleReminders(for occurrences: [BillOccurrence]) async throws

    /// Cancels reminders for specific occurrences
    func cancelReminders(for occurrenceIDs: [BillOccurrence.OccurrenceID]) async

    /// Cancels ALL reminders for a bill (used on bill deletion)
    func cancelAllReminders(forBillID billID: String) async

    /// Reschedules after due date change
    func rescheduleReminders(
        forBillID billID: String,
        newOccurrences: [BillOccurrence]
    ) async throws

    // MARK: - Digest

    /// Schedules daily digest notification
    func scheduleDigest(
        billsDueCount: Int,
        totalAmount: Decimal?,
        currencyCode: String?
    ) async throws

    func cancelDigest() async

    // MARK: - Badge

    /// Updates badge to reflect current unpaid count
    func updateBadge(unpaidCount: Int) async

    /// Clears badge
    func clearBadge() async
}
