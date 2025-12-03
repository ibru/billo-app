//  Created by Jiri Urbasek on 12/02/25.

import Foundation
import UserNotifications

/// Thin wrapper for UNUserNotificationCenter to enable testability
protocol UNNotificationCenterProtocol: Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers: [String])
    func removeAllPendingNotificationRequests()
    func setBadgeCount(_ count: Int) async throws
}

// MARK: - Production Conformance

extension UNUserNotificationCenter: UNNotificationCenterProtocol {
    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationSettings()
        return settings.authorizationStatus
    }
}
