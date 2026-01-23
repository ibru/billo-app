//  Created by Jiri Urbasek on 12/03/25.

import Testing
import Dispatch
import SwiftUI
import UserNotifications
@testable import Billo

@Suite("NotificationSettingsModel") @MainActor
struct NotificationSettingsModelTests {

    @Test
    func whenLoadingAuthorizationStatus_thenModelUpdates() async {
        let (sut, coordinator, _, _) = makeSUT()
        coordinator.authorizationStatusToReturn = .provisional

        await sut.loadAuthorizationStatus()

        #expect(sut.authorizationStatus == .provisional)
    }

    @Test
    func whenSceneBecomesActive_thenRefreshesAuthorizationStatus() async {
        let (sut, coordinator, _, _) = makeSUT()
        coordinator.authorizationStatusToReturn = .provisional

        await sut.onScenePhaseChange(.active)

        #expect(coordinator.currentStatusCallCount == 1)
        #expect(sut.authorizationStatus == .provisional)
    }

    @Test
    func whenSceneIsBackground_thenDoesNotRefresh() async {
        let (sut, coordinator, _, _) = makeSUT()

        await sut.onScenePhaseChange(.background)

        #expect(coordinator.currentStatusCallCount == 0)
    }

    @Test
    func whenTogglingOnAndPermissionGranted_thenEnablesPreference() async {
        let (sut, coordinator, preferences, scheduler) = makeSUT()
        coordinator.authorizationStatusToReturn = .authorized
        coordinator.requestAuthorizationResult = true

        await sut.toggleRemindersAsync(to: true)

        #expect(preferences.remindersEnabled)
        #expect(sut.authorizationStatus == .authorized)
        #expect(sut.showPermissionDeniedAlert == false)
        #expect(scheduler.scheduleCallCount == 1)
    }

    @Test
    func whenTogglingOnAndPermissionRequestDenied_thenKeepsPreferenceOff() async {
        let (sut, coordinator, preferences, scheduler) = makeSUT()
        coordinator.authorizationStatusToReturn = .denied
        coordinator.requestAuthorizationResult = false

        await sut.toggleRemindersAsync(to: true)

        #expect(preferences.remindersEnabled == false)
        #expect(sut.showPermissionDeniedAlert)
        #expect(scheduler.scheduleCallCount == 0)
    }

    @Test
    func whenTogglingOnAndAlreadyAuthorized_thenEnablesWithoutAlert() async {
        let (sut, _, preferences, scheduler) = makeSUT()
        sut.setAuthorizationStatusForTesting(.authorized)

        await sut.toggleRemindersAsync(to: true)

        #expect(preferences.remindersEnabled)
        #expect(sut.showPermissionDeniedAlert == false)
        #expect(scheduler.scheduleCallCount == 1)
    }

    @Test
    func whenTogglingOff_thenDisablesPreference() async {
        let (sut, _, preferences, scheduler) = makeSUT()
        preferences.remindersEnabled = true

        await sut.toggleRemindersAsync(to: false)

        #expect(preferences.remindersEnabled == false)
        #expect(scheduler.scheduleCallCount == 1)
    }

    @Test
    func whenEffectiveStateCalculated_thenRequiresPreferenceAndAuthorization() {
        let (sut, _, preferences, _) = makeSUT()
        preferences.remindersEnabled = true

        sut.setAuthorizationStatusForTesting(.authorized)
        #expect(sut.effectiveReminderToggleState)

        sut.setAuthorizationStatusForTesting(.denied)
        #expect(sut.effectiveReminderToggleState == false)
    }

    @Test
    func whenUpdatingOffsets_thenModelExposesUpdatedValue() {
        let (sut, _, preferences, scheduler) = makeSUT()

        sut.setReminderOffsets([0, 7])

        #expect(sut.reminderOffsets == [0, 7])
        #expect(preferences.reminderOffsets == [0, 7])
        #expect(scheduler.scheduleCallCount == 1)
    }

    @Test
    func whenEnablingDigest_thenSchedulesRefresh() {
        let (sut, _, preferences, scheduler) = makeSUT()

        sut.setDigestEnabled(true)

        #expect(preferences.digestEnabled)
        #expect(scheduler.scheduleCallCount == 1)
    }

    @Test
    func whenUpdatingBadgeMode_thenSchedulesRefresh() {
        let (sut, _, preferences, scheduler) = makeSUT()

        sut.setBadgeMode(.daysBefore(3))

        #expect(preferences.badgeMode == .daysBefore(3))
        #expect(scheduler.scheduleCallCount == 1)
    }

    @Test
    func whenOpenSettingsCalled_thenHandlerInvoked() {
        let (sut, _, _, _, settingsSpy) = makeSUTWithSettingsSpy()

        sut.openSettings()

        #expect(settingsSpy.wasCalled)
    }

    // MARK: - Toggle Reminder Offset

    @Test
    func whenTogglingOffsetNotInCurrentList_thenAddsOffsetSorted() {
        let (sut, _, preferences, _) = makeSUT()
        preferences.reminderOffsets = [0, 3]

        sut.toggleReminderOffset(7)

        #expect(sut.reminderOffsets == [0, 3, 7])
    }

    @Test
    func whenTogglingOffsetAlreadyInList_thenRemovesOffset() {
        let (sut, _, preferences, _) = makeSUT()
        preferences.reminderOffsets = [0, 3, 7]

        sut.toggleReminderOffset(3)

        #expect(sut.reminderOffsets == [0, 7])
    }

    @Test
    func whenTogglingLastRemainingOffset_thenKeepsOffset() {
        let (sut, _, preferences, _) = makeSUT()
        preferences.reminderOffsets = [3]

        sut.toggleReminderOffset(3)

        #expect(sut.reminderOffsets == [3], "Cannot remove the last offset")
    }

    @Test
    func whenTogglingOffsetWithTwoRemaining_thenAllowsRemoval() {
        let (sut, _, preferences, _) = makeSUT()
        preferences.reminderOffsets = [0, 3]

        sut.toggleReminderOffset(0)

        #expect(sut.reminderOffsets == [3])
    }
}

// MARK: - makeSUT

@MainActor
private func makeSUT() -> (
    NotificationSettingsModel,
    NotificationCoordinatorSpy,
    NotificationPreferencesSpy,
    NotificationRefreshSchedulerSpy
) {
    let preferences = NotificationPreferencesSpy()
    let coordinator = NotificationCoordinatorSpy()
    let scheduler = NotificationRefreshSchedulerSpy()
    let sut = NotificationSettingsModel(
        preferences: preferences,
        coordinator: coordinator,
        openSettingsHandler: {},
        refreshScheduler: scheduler,
        taskRunner: { task in
            Task { await task() }
        }
    )
    return (sut, coordinator, preferences, scheduler)
}

@MainActor
private func makeSUTWithSettingsSpy() -> (
    NotificationSettingsModel,
    NotificationCoordinatorSpy,
    NotificationPreferencesSpy,
    NotificationRefreshSchedulerSpy,
    SettingsSpy
) {
    let preferences = NotificationPreferencesSpy()
    let coordinator = NotificationCoordinatorSpy()
    let scheduler = NotificationRefreshSchedulerSpy()
    let settingsSpy = SettingsSpy()
    let sut = NotificationSettingsModel(
        preferences: preferences,
        coordinator: coordinator,
        openSettingsHandler: { settingsSpy.call() },
        refreshScheduler: scheduler,
        taskRunner: { task in
            Task { await task() }
        }
    )
    return (sut, coordinator, preferences, scheduler, settingsSpy)
}

// MARK: - Test Doubles

private final class NotificationPreferencesSpy: NotificationPreferencesProviding {
    var remindersEnabled: Bool = false
    var reminderOffsets: [Int] = NotificationPreferencesStore.defaultReminderOffsets
    var reminderTime: DateComponents = NotificationPreferencesStore.defaultReminderTime
    var digestEnabled: Bool = false
    var digestLookaheadDays: Int = NotificationPreferencesStore.defaultDigestLookaheadDays
    var digestTime: DateComponents = NotificationPreferencesStore.defaultDigestTime
    var badgeMode: BadgeMode = .never

    func setRemindersEnabled(_ enabled: Bool) { remindersEnabled = enabled }
    func setReminderOffsets(_ offsets: [Int]) { reminderOffsets = offsets }
    func setReminderTime(_ time: DateComponents) { reminderTime = time }
    func setDigestEnabled(_ enabled: Bool) { digestEnabled = enabled }
    func setDigestLookaheadDays(_ days: Int) { digestLookaheadDays = days }
    func setDigestTime(_ time: DateComponents) { digestTime = time }
    func setBadgeMode(_ mode: BadgeMode) { badgeMode = mode }
}

@MainActor
private final class NotificationRefreshSchedulerSpy: NotificationRefreshScheduling {
    private(set) var scheduleCallCount = 0
    func scheduleRefresh() {
        scheduleCallCount += 1
    }
}

private final class SettingsSpy {
    private(set) var wasCalled = false
    func call() { wasCalled = true }
}
