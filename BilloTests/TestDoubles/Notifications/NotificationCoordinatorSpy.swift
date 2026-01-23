//  Created by Jiri Urbasek on 12/02/25.

import Foundation
import UserNotifications
@testable import Billo

final class NotificationCoordinatorSpy: NotificationCoordinating, @unchecked Sendable {
    // MARK: - Captured calls

    private(set) var cancelRemindersCalls: [[BillOccurrence.OccurrenceID]] = []
    private(set) var cancelAllRemindersCalls: [String] = []  // billIDs
    private(set) var scheduleRemindersCalls: [[BillOccurrence]] = []
    private(set) var rescheduleRemindersCalls: [(billID: String, occurrences: [BillOccurrence])] = []
    private(set) var updateBadgeCalls: [Int] = []
    private(set) var clearBadgeCalls: Int = 0
    private(set) var refreshAllNotificationsCalls: [[Bill]] = []
    private(set) var scheduleDigestCalls: [(
        upcomingItems: [NotificationContentBuilder.NotificationDigestItem],
        overdueItems: [NotificationContentBuilder.NotificationDigestItem],
        lookaheadDays: Int,
        notificationDate: Date,
        identifier: String
    )] = []
    private(set) var cancelDigestCalls: Int = 0
    private(set) var currentStatusCallCount: Int = 0
    private(set) var requestAuthorizationCallCount: Int = 0

    // MARK: - Stubbed responses

    var authorizationStatusToReturn: UNAuthorizationStatus = .authorized
    var requestAuthorizationResult: Bool = true
    var refreshAllNotificationsError: (any Error)?

    // MARK: - Protocol implementation

    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        currentStatusCallCount += 1
        return authorizationStatusToReturn
    }

    func requestAuthorization() async throws -> Bool {
        requestAuthorizationCallCount += 1
        return requestAuthorizationResult
    }

    func refreshAllNotifications(for bills: [Bill]) async throws {
        refreshAllNotificationsCalls.append(bills)
        if let refreshAllNotificationsError {
            throw refreshAllNotificationsError
        }
    }

    func scheduleReminders(for occurrences: [BillOccurrence]) async throws {
        scheduleRemindersCalls.append(occurrences)
    }

    func cancelReminders(for occurrenceIDs: [BillOccurrence.OccurrenceID]) async {
        cancelRemindersCalls.append(occurrenceIDs)
    }

    func cancelAllReminders(forBillID billID: String) async {
        cancelAllRemindersCalls.append(billID)
    }

    func rescheduleReminders(forBillID billID: String, newOccurrences: [BillOccurrence]) async throws {
        rescheduleRemindersCalls.append((billID, newOccurrences))
    }

    func scheduleDigest(
        upcomingItems: [NotificationContentBuilder.NotificationDigestItem],
        overdueItems: [NotificationContentBuilder.NotificationDigestItem],
        lookaheadDays: Int,
        notificationDate: Date,
        identifier: String
    ) async throws {
        scheduleDigestCalls.append((
            upcomingItems: upcomingItems,
            overdueItems: overdueItems,
            lookaheadDays: lookaheadDays,
            notificationDate: notificationDate,
            identifier: identifier
        ))
    }

    func cancelDigest() async {
        cancelDigestCalls += 1
    }

    func updateBadge(unpaidCount: Int) async {
        updateBadgeCalls.append(unpaidCount)
    }

    func clearBadge() async {
        clearBadgeCalls += 1
    }
}
