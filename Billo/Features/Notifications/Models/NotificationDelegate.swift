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
    /// Live entitlement for the free-tier display cap. Late-bound to
    /// `StoreKitManager.isPro` during app setup; a response arriving before
    /// then falls back to the persisted entitlement cache — the same
    /// optimistic value `StoreKitManager` itself trusts at launch.
    var isProProvider: (@MainActor @Sendable () -> Bool)?

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

            let isPro = isProProvider?() ?? UserDefaultsProEntitlementCache().isPro
            let handler = NotificationActionHandler()
            await handler.handleMarkPaid(
                notificationIdentifier: response.notification.request.identifier,
                modelContainer: container,
                notificationCoordinator: coordinator,
                notificationPreferences: preferences,
                isPro: isPro,
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
