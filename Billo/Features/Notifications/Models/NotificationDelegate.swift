//  Created by Jiri Urbasek on 12/02/25.

import Foundation
import UserNotifications
import SwiftData

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    weak var modelContainer: ModelContainer?
    weak var notificationCoordinator: NotificationCoordinator?
    var notificationPreferences: NotificationPreferencesStore?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            defer { completionHandler() }

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
                notificationPreferences: preferences
            )
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
