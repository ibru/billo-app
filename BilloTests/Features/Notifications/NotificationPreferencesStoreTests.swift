//  Created by Jiri Urbasek on 12/02/25.

import Testing
import Foundation
@testable import Billo

@Suite("NotificationPreferencesStore")
@MainActor
struct NotificationPreferencesStoreTests {

    // MARK: - Defaults

    @Suite("defaults")
    @MainActor
    struct Defaults {
        @Test
        func whenFirstLaunch_thenRemindersEnabledByDefault() {
            let (sut, _) = makeSUT()

            #expect(sut.remindersEnabled == true)
        }

        @Test
        func whenFirstLaunch_thenDefaultOffsetsAreDayOfAnd3Days() {
            let (sut, _) = makeSUT()

            #expect(sut.reminderOffsets == [0, 3])
        }

        @Test
        func whenFirstLaunch_thenReminderTimeIs9AM() {
            let (sut, _) = makeSUT()

            #expect(sut.reminderTime.hour == 9)
            #expect(sut.reminderTime.minute == 0)
        }

        @Test
        func whenFirstLaunch_thenDigestDisabledByDefault() {
            let (sut, _) = makeSUT()

            #expect(sut.digestEnabled == false)
        }

        @Test
        func whenFirstLaunch_thenDigestLookaheadIs5Days() {
            let (sut, _) = makeSUT()

            #expect(sut.digestLookaheadDays == 5)
        }

        @Test
        func whenFirstLaunch_thenDigestTimeIs9AM() {
            let (sut, _) = makeSUT()

            #expect(sut.digestTime.hour == 9)
            #expect(sut.digestTime.minute == 0)
        }

        @Test
        func whenFirstLaunch_thenBadgeModeIs3DaysBefore() {
            let (sut, _) = makeSUT()

            #expect(sut.badgeMode == .daysBefore(3))
        }
    }

    // MARK: - Persistence

    @Suite("persistence")
    @MainActor
    struct Persistence {
        @Test
        func whenRemindersEnabledSet_thenPersistsAcrossInstances() {
            let userDefaults = UserDefaults(suiteName: UUID().uuidString)!

            // Write with first instance
            let sut1 = NotificationPreferencesStore(userDefaults: userDefaults)
            sut1.setRemindersEnabled(false)

            // Read with new instance
            let sut2 = NotificationPreferencesStore(userDefaults: userDefaults)
            #expect(sut2.remindersEnabled == false)
        }

        @Test
        func whenReminderOffsetsSet_thenPersistsArray() {
            let userDefaults = UserDefaults(suiteName: UUID().uuidString)!

            let sut1 = NotificationPreferencesStore(userDefaults: userDefaults)
            sut1.setReminderOffsets([0, 5, 7])

            let sut2 = NotificationPreferencesStore(userDefaults: userDefaults)
            #expect(sut2.reminderOffsets == [0, 5, 7])
        }

        @Test
        func whenReminderTimeSet_thenPersistsAcrossInstances() {
            let userDefaults = UserDefaults(suiteName: UUID().uuidString)!

            let sut1 = NotificationPreferencesStore(userDefaults: userDefaults)
            sut1.setReminderTime(DateComponents(hour: 14, minute: 30))

            let sut2 = NotificationPreferencesStore(userDefaults: userDefaults)
            #expect(sut2.reminderTime.hour == 14)
            #expect(sut2.reminderTime.minute == 30)
        }

        @Test
        func whenDigestEnabledSet_thenPersists() {
            let userDefaults = UserDefaults(suiteName: UUID().uuidString)!

            let sut1 = NotificationPreferencesStore(userDefaults: userDefaults)
            sut1.setDigestEnabled(true)

            let sut2 = NotificationPreferencesStore(userDefaults: userDefaults)
            #expect(sut2.digestEnabled == true)
        }

        @Test
        func whenDigestLookaheadDaysSet_thenPersists() {
            let userDefaults = UserDefaults(suiteName: UUID().uuidString)!

            let sut1 = NotificationPreferencesStore(userDefaults: userDefaults)
            sut1.setDigestLookaheadDays(7)

            let sut2 = NotificationPreferencesStore(userDefaults: userDefaults)
            #expect(sut2.digestLookaheadDays == 7)
        }

        @Test
        func whenDigestTimeSet_thenPersists() {
            let userDefaults = UserDefaults(suiteName: UUID().uuidString)!

            let sut1 = NotificationPreferencesStore(userDefaults: userDefaults)
            sut1.setDigestTime(DateComponents(hour: 20, minute: 0))

            let sut2 = NotificationPreferencesStore(userDefaults: userDefaults)
            #expect(sut2.digestTime.hour == 20)
            #expect(sut2.digestTime.minute == 0)
        }

        @Test
        func whenBadgeModeSet_thenPersists() {
            let userDefaults = UserDefaults(suiteName: UUID().uuidString)!

            let sut1 = NotificationPreferencesStore(userDefaults: userDefaults)
            sut1.setBadgeMode(.never)

            let sut2 = NotificationPreferencesStore(userDefaults: userDefaults)
            #expect(sut2.badgeMode == .never)
        }
    }

    // MARK: - Offset Validation

    @Suite("offsetValidation")
    @MainActor
    struct OffsetValidation {
        @Test
        func whenEmptyOffsetsProvided_thenFallsBackToDefault() {
            let (sut, _) = makeSUT()

            sut.setReminderOffsets([])

            #expect(sut.reminderOffsets == [0, 3]) // Default
        }

        @Test
        func whenInvalidOffsetsProvided_thenFiltersToValid() {
            let (sut, _) = makeSUT()

            sut.setReminderOffsets([0, 2, 3, 99]) // 2 and 99 are invalid

            #expect(sut.reminderOffsets == [0, 3])
        }

        @Test
        func whenAllInvalidOffsetsProvided_thenFallsBackToDefault() {
            let (sut, _) = makeSUT()

            sut.setReminderOffsets([1, 2, 99])

            #expect(sut.reminderOffsets == [0, 3])
        }

        @Test
        func whenValidOffsetsProvided_thenStoresAll() {
            let (sut, _) = makeSUT()

            sut.setReminderOffsets([0, 3, 5, 7])

            #expect(sut.reminderOffsets == [0, 3, 5, 7])
        }
    }

    // MARK: - BadgeMode Encoding

    @Suite("badgeModeEncoding")
    @MainActor
    struct BadgeModeEncoding {
        @Test
        func whenBadgeModeNever_thenEncodesAndDecodes() {
            let (sut, _) = makeSUT()

            sut.setBadgeMode(.never)

            #expect(sut.badgeMode == .never)
        }

        @Test
        func whenBadgeModeDueAndOverdue_thenEncodesAndDecodes() {
            let (sut, _) = makeSUT()

            sut.setBadgeMode(.dueAndOverdue)

            #expect(sut.badgeMode == .dueAndOverdue)
        }

        @Test
        func whenBadgeModeDaysBefore_thenEncodesAndDecodes() {
            let (sut, _) = makeSUT()

            sut.setBadgeMode(.daysBefore(7))

            #expect(sut.badgeMode == .daysBefore(7))
        }
    }

    // MARK: - Constants

    @Suite("constants")
    @MainActor
    struct Constants {
        @Test
        func whenAvailableOffsets_thenContainsExpectedValues() {
            let offsets = NotificationPreferencesStore.availableOffsets

            #expect(offsets == [0, 3, 5, 7])
        }

        @Test
        func whenDefaultReminderOffsets_thenContainsDayOfAnd3Days() {
            let offsets = NotificationPreferencesStore.defaultReminderOffsets

            #expect(offsets == [0, 3])
        }

        @Test
        func whenDefaultReminderTime_thenIs9AM() {
            let time = NotificationPreferencesStore.defaultReminderTime

            #expect(time.hour == 9)
            #expect(time.minute == 0)
        }

        @Test
        func whenDefaultDigestLookaheadDays_thenIs5() {
            #expect(NotificationPreferencesStore.defaultDigestLookaheadDays == 5)
        }

        @Test
        func whenDefaultDigestTime_thenIs9AM() {
            let time = NotificationPreferencesStore.defaultDigestTime

            #expect(time.hour == 9)
            #expect(time.minute == 0)
        }

        @Test
        func whenDefaultBadgeMode_thenIs3DaysBefore() {
            #expect(NotificationPreferencesStore.defaultBadgeMode == .daysBefore(3))
        }
    }
}

// MARK: - makeSUT

@MainActor
private func makeSUT() -> (sut: NotificationPreferencesStore, userDefaults: UserDefaults) {
    let userDefaults = UserDefaults(suiteName: UUID().uuidString)!
    let sut = NotificationPreferencesStore(userDefaults: userDefaults)
    return (sut, userDefaults)
}
