//  Created by Jiri Urbasek on 12/03/25.

import UserNotifications

enum NotificationToggleLogic {
    /// Returns true if system authorization allows delivering notifications for reminders.
    nonisolated static func isAuthorized(for status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    /// Effective reminder toggle value combining user preference and system permission.
    nonisolated static func effectiveState(
        preferenceEnabled: Bool,
        authorizationStatus: UNAuthorizationStatus
    ) -> Bool {
        preferenceEnabled && isAuthorized(for: authorizationStatus)
    }
}
