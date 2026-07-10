//  Created by Jiri Urbasek on 12/02/25.

import Foundation
import UserNotifications
import SwiftData

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    weak var modelContainer: ModelContainer?
    weak var notificationCoordinator: NotificationCoordinator?
    var notificationPreferences: NotificationPreferencesStore?
    /// Late-bound like the refs above; a response arriving before app setup
    /// finishes simply goes untracked (same behavior the model refs have).
    var analyticsCapture: (@MainActor @Sendable (AnalyticsEvent) -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            defer { completionHandler() }

            let kind = Self.analyticsKind(
                forCategory: response.notification.request.content.categoryIdentifier
            )
            switch response.actionIdentifier {
            case UNNotificationDefaultActionIdentifier:
                analyticsCapture?(.notificationOpened(kind: kind))
            case UNNotificationDismissActionIdentifier:
                analyticsCapture?(.notificationDismissed(kind: kind))
            default:
                break
            }

            guard response.actionIdentifier == NotificationAction.markPaid,
                  let container = modelContainer,
                  let coordinator = notificationCoordinator,
                  let preferences = notificationPreferences else {
                return
            }

            let handler = NotificationActionHandler()
            await handler.handleMarkPaid(
                notificationIdentifier: response.notification.request.identifier,
                modelContainer: container,
                notificationCoordinator: coordinator,
                notificationPreferences: preferences,
                analyticsCapture: analyticsCapture
            )
        }
    }

    private static func analyticsKind(forCategory categoryIdentifier: String) -> String {
        switch categoryIdentifier {
        case NotificationCategory.billReminder: "bill_reminder"
        case NotificationCategory.dailyDigest: "daily_digest"
        default: "unknown"
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is open
        completionHandler([.banner, .sound, .badge])
    }
}
