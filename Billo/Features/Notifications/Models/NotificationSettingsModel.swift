//  Created by Jiri Urbasek on 12/03/25.

import Foundation
import Observation
import SwiftUI
import UserNotifications

@MainActor
@Observable
final class NotificationSettingsModel {
    @ObservationIgnored private let preferences: NotificationPreferencesProviding
    @ObservationIgnored private let coordinator: NotificationCoordinating
    @ObservationIgnored private let openSettingsHandler: () -> Void
    @ObservationIgnored private let refreshScheduler: NotificationRefreshScheduling
    /// Injectable runner to control how async work is scheduled; tests can override to run immediately without blocking.
    @ObservationIgnored private let taskRunner: (@escaping @Sendable () async -> Void) -> Void
    @ObservationIgnored private let analyticsCapture: (AnalyticsEvent) -> Void

    // Observation tick to notify view when preferences are mutated through the model.
    private var changeTick: Int = 0

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var showPermissionDeniedAlert: Bool = false

    init(
        preferences: NotificationPreferencesProviding,
        coordinator: NotificationCoordinating,
        openSettingsHandler: @escaping () -> Void,
        refreshScheduler: NotificationRefreshScheduling = NoopNotificationRefreshScheduler(),
        taskRunner: @escaping (@escaping @Sendable () async -> Void) -> Void = { task in
            Task { await task() }
        },
        analyticsCapture: @escaping (AnalyticsEvent) -> Void = { _ in }
    ) {
        self.preferences = preferences
        self.coordinator = coordinator
        self.openSettingsHandler = openSettingsHandler
        self.refreshScheduler = refreshScheduler
        self.taskRunner = taskRunner
        self.analyticsCapture = analyticsCapture
    }

    // MARK: - Derived State

    var effectiveReminderToggleState: Bool {
        _ = changeTick  // keep observation in sync with preference changes
        return NotificationToggleLogic.effectiveState(
            preferenceEnabled: preferences.remindersEnabled,
            authorizationStatus: authorizationStatus
        )
    }

    // MARK: - View Exposure (Preferences)

    var reminderOffsets: [Int] {
        _ = changeTick
        return preferences.reminderOffsets
    }

    var reminderTime: DateComponents {
        _ = changeTick
        return preferences.reminderTime
    }

    var digestEnabled: Bool {
        _ = changeTick
        return preferences.digestEnabled
    }

    var digestLookaheadDays: Int {
        _ = changeTick
        return preferences.digestLookaheadDays
    }

    var digestTime: DateComponents {
        _ = changeTick
        return preferences.digestTime
    }

    var badgeMode: BadgeMode {
        _ = changeTick
        return preferences.badgeMode
    }

    // MARK: - Intents

    func toggleReminders(to newValue: Bool) {
        taskRunner { [weak self] in
            await self?.toggleRemindersAsync(to: newValue)
        }
    }

    /// Async variant used for testing to avoid scheduling onto another Task.
    func toggleRemindersAsync(to newValue: Bool) async {
        let wasEnabled = preferences.remindersEnabled

        if newValue {
            await handleEnableRemindersTask()
        } else {
            preferences.setRemindersEnabled(false)
        }

        notifyChange()
        if preferences.remindersEnabled != wasEnabled {
            // Final state only — enabling can fail on denied permission,
            // in which case nothing changed and nothing is captured.
            analyticsCapture(.notificationRemindersToggled(enabled: preferences.remindersEnabled))
            refreshScheduler.scheduleRefresh()
        }
    }

    func setReminderOffsets(_ offsets: [Int]) {
        preferences.setReminderOffsets(offsets)
        analyticsCapture(.notificationScheduleAdjusted(field: "reminder_offsets"))
        notifyChange()
        refreshScheduler.scheduleRefresh()
    }

    /// Toggles the given offset on/off. Does not allow removing the last remaining offset.
    func toggleReminderOffset(_ offset: Int) {
        var current = preferences.reminderOffsets

        if current.contains(offset) {
            guard current.count > 1 else { return }
            current.removeAll { $0 == offset }
        } else {
            current.append(offset)
            current.sort()
        }

        preferences.setReminderOffsets(current)
        analyticsCapture(.notificationScheduleAdjusted(field: "reminder_offsets"))
        notifyChange()
        refreshScheduler.scheduleRefresh()
    }

    func setReminderTime(_ time: DateComponents) {
        preferences.setReminderTime(time)
        analyticsCapture(.notificationScheduleAdjusted(field: "reminder_time"))
        notifyChange()
        refreshScheduler.scheduleRefresh()
    }

    func setDigestEnabled(_ enabled: Bool) {
        preferences.setDigestEnabled(enabled)
        analyticsCapture(.notificationDigestToggled(enabled: enabled))
        notifyChange()
        refreshScheduler.scheduleRefresh()
    }

    func setDigestLookaheadDays(_ days: Int) {
        preferences.setDigestLookaheadDays(days)
        analyticsCapture(.notificationScheduleAdjusted(field: "digest_lookahead"))
        notifyChange()
        refreshScheduler.scheduleRefresh()
    }

    func setDigestTime(_ time: DateComponents) {
        preferences.setDigestTime(time)
        analyticsCapture(.notificationScheduleAdjusted(field: "digest_time"))
        notifyChange()
        refreshScheduler.scheduleRefresh()
    }

    func setBadgeMode(_ mode: BadgeMode) {
        preferences.setBadgeMode(mode)
        analyticsCapture(.notificationBadgeModeChanged(mode: Self.analyticsValue(for: mode)))
        notifyChange()
        refreshScheduler.scheduleRefresh()
    }

    private static func analyticsValue(for mode: BadgeMode) -> String {
        switch mode {
        case .never: "never"
        case .dueAndOverdue: "due_and_overdue"
        case .daysBefore(let days): "days_before_\(days)"
        }
    }

    func openSettings() {
        openSettingsHandler()
    }

    // MARK: - Lifecycle

    func loadAuthorizationStatus() async {
        authorizationStatus = await coordinator.currentAuthorizationStatus()
    }

    func onScenePhaseChange(_ phase: ScenePhase) async {
        guard phase == .active else { return }
        await loadAuthorizationStatus()
    }

    // MARK: - Private

    private func handleEnableReminders() {
        taskRunner { [weak self] in
            await self?.handleEnableRemindersTask()
        }
    }

    private func handleEnableRemindersTask() async {
        switch authorizationStatus {
        case .notDetermined:
            let granted: Bool
            do {
                granted = try await coordinator.requestAuthorization()
            } catch {
                granted = false
            }
            analyticsCapture(.notificationPermissionResponded(granted: granted))
            authorizationStatus = await coordinator.currentAuthorizationStatus()

            if granted && NotificationToggleLogic.isAuthorized(for: authorizationStatus) {
                preferences.setRemindersEnabled(true)
            } else {
                showPermissionDeniedAlert = true
            }

        case .denied:
            showPermissionDeniedAlert = true

        case .authorized, .provisional:
            preferences.setRemindersEnabled(true)
#if os(iOS)
        case .ephemeral:
            preferences.setRemindersEnabled(true)
#endif

        @unknown default:
            break
        }

        notifyChange()
    }

    private func notifyChange() {
        changeTick &+= 1
    }

#if DEBUG
    func setAuthorizationStatusForTesting(_ status: UNAuthorizationStatus) {
        authorizationStatus = status
    }
#endif
}
