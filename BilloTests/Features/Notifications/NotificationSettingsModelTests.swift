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
        let (sut, coordinator, _) = makeSUT()
        coordinator.authorizationStatusToReturn = .provisional

        await sut.loadAuthorizationStatus()

        #expect(sut.authorizationStatus == .provisional)
    }

    @Test
    func whenSceneBecomesActive_thenRefreshesAuthorizationStatus() async {
        let (sut, coordinator, _) = makeSUT()
        coordinator.authorizationStatusToReturn = .provisional

        await sut.onScenePhaseChange(.active)

        #expect(coordinator.currentStatusCallCount == 1)
        #expect(sut.authorizationStatus == .provisional)
    }

    @Test
    func whenSceneIsBackground_thenDoesNotRefresh() async {
        let (sut, coordinator, _) = makeSUT()

        await sut.onScenePhaseChange(.background)

        #expect(coordinator.currentStatusCallCount == 0)
    }

    @Test
    func whenTogglingOnAndPermissionGranted_thenEnablesPreference() async {
        let (sut, coordinator, preferences) = makeSUT()
        coordinator.authorizationStatusToReturn = .authorized
        coordinator.requestAuthorizationResult = true

        await sut.toggleRemindersAsync(to: true)

        #expect(preferences.remindersEnabled)
        #expect(sut.authorizationStatus == .authorized)
        #expect(sut.showPermissionDeniedAlert == false)
    }

    @Test
    func whenTogglingOnAndPermissionRequestDenied_thenKeepsPreferenceOff() async {
        let (sut, coordinator, preferences) = makeSUT()
        coordinator.authorizationStatusToReturn = .denied
        coordinator.requestAuthorizationResult = false

        await sut.toggleRemindersAsync(to: true)

        #expect(preferences.remindersEnabled == false)
        #expect(sut.showPermissionDeniedAlert)
    }

    @Test
    func whenTogglingOnAndAlreadyAuthorized_thenEnablesWithoutAlert() async {
        let (sut, _, preferences) = makeSUT()
        sut.setAuthorizationStatusForTesting(.authorized)

        await sut.toggleRemindersAsync(to: true)

        #expect(preferences.remindersEnabled)
        #expect(sut.showPermissionDeniedAlert == false)
    }

    @Test
    func whenTogglingOff_thenDisablesPreference() async {
        let (sut, _, preferences) = makeSUT()
        preferences.remindersEnabled = true

        await sut.toggleRemindersAsync(to: false)

        #expect(preferences.remindersEnabled == false)
    }

    @Test
    func whenEffectiveStateCalculated_thenRequiresPreferenceAndAuthorization() {
        let (sut, _, preferences) = makeSUT()
        preferences.remindersEnabled = true

        sut.setAuthorizationStatusForTesting(.authorized)
        #expect(sut.effectiveReminderToggleState)

        sut.setAuthorizationStatusForTesting(.denied)
        #expect(sut.effectiveReminderToggleState == false)
    }

    @Test
    func whenUpdatingOffsets_thenModelExposesUpdatedValue() {
        let (sut, _, preferences) = makeSUT()

        sut.setReminderOffsets([0, 7])

        #expect(sut.reminderOffsets == [0, 7])
        #expect(preferences.reminderOffsets == [0, 7])
    }

    @Test
    func whenOpenSettingsCalled_thenHandlerInvoked() {
        let (sut, _, _, settingsSpy) = makeSUTWithSettingsSpy()

        sut.openSettings()

        #expect(settingsSpy.wasCalled)
    }

    // MARK: - Toggle Reminder Offset

    @Test
    func whenTogglingOffsetNotInCurrentList_thenAddsOffsetSorted() {
        let (sut, _, preferences) = makeSUT()
        preferences.reminderOffsets = [0, 3]

        sut.toggleReminderOffset(7)

        #expect(sut.reminderOffsets == [0, 3, 7])
    }

    @Test
    func whenTogglingOffsetAlreadyInList_thenRemovesOffset() {
        let (sut, _, preferences) = makeSUT()
        preferences.reminderOffsets = [0, 3, 7]

        sut.toggleReminderOffset(3)

        #expect(sut.reminderOffsets == [0, 7])
    }

    @Test
    func whenTogglingLastRemainingOffset_thenKeepsOffset() {
        let (sut, _, preferences) = makeSUT()
        preferences.reminderOffsets = [3]

        sut.toggleReminderOffset(3)

        #expect(sut.reminderOffsets == [3], "Cannot remove the last offset")
    }

    @Test
    func whenTogglingOffsetWithTwoRemaining_thenAllowsRemoval() {
        let (sut, _, preferences) = makeSUT()
        preferences.reminderOffsets = [0, 3]

        sut.toggleReminderOffset(0)

        #expect(sut.reminderOffsets == [3])
    }
}

// MARK: - makeSUT

@MainActor
private func makeSUT() -> (NotificationSettingsModel, NotificationCoordinatorSpy, NotificationPreferencesSpy) {
    let preferences = NotificationPreferencesSpy()
    let coordinator = NotificationCoordinatorSpy()
    let sut = NotificationSettingsModel(
        preferences: preferences,
        coordinator: coordinator,
        openSettingsHandler: {},
        taskRunner: { task in
            Task { await task() }
        }
    )
    return (sut, coordinator, preferences)
}

@MainActor
private func makeSUTWithSettingsSpy() -> (NotificationSettingsModel, NotificationCoordinatorSpy, NotificationPreferencesSpy, SettingsSpy) {
    let preferences = NotificationPreferencesSpy()
    let coordinator = NotificationCoordinatorSpy()
    let settingsSpy = SettingsSpy()
    let sut = NotificationSettingsModel(
        preferences: preferences,
        coordinator: coordinator,
        openSettingsHandler: { settingsSpy.call() },
        taskRunner: { task in
            Task { await task() }
        }
    )
    return (sut, coordinator, preferences, settingsSpy)
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

private final class SettingsSpy {
    private(set) var wasCalled = false
    func call() { wasCalled = true }
}
