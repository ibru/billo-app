//  Created by Jiri Urbasek on 12/04/25.

import Foundation

@MainActor
protocol BillsRefreshing: Sendable {
    func refresh() throws
    var bills: [Bill] { get }
}

/// Ensures badges and notifications are refreshed with up-to-date bill data
@MainActor
struct AppNotificationRefresher: Sendable {
    func refreshAndReschedule(
        billsModel: BillsRefreshing,
        coordinator: NotificationCoordinating
    ) async {
        do {
            try billsModel.refresh()
        } catch {
            print("[Notifications] Failed to refresh bills before scheduling: \(error)")
        }

        do {
            try await coordinator.refreshAllNotifications(for: billsModel.bills)
        } catch {
            print("[Notifications] Failed to refresh notifications after app became active: \(error)")
        }
    }
}
