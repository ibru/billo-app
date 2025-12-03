//  Created by Jiri Urbasek on 12/03/25.

import Testing
import UserNotifications
@testable import Billo

@Suite("Notification Toggle State") @MainActor
struct NotificationToggleStateTests {

    @Test
    func whenPreferenceEnabledAndStatusAllowsNotifications_thenToggleIsOn() {
        for status in [UNAuthorizationStatus.authorized, .provisional, .ephemeral] {
            let isOn = makeEffectiveState(preferenceEnabled: true, status: status)
            #expect(isOn)
        }
    }

    @Test(arguments: [UNAuthorizationStatus.notDetermined, .denied])
    func whenPreferenceEnabledButStatusBlocksNotifications_thenToggleIsOff(_ status: UNAuthorizationStatus) {
        let isOn = makeEffectiveState(preferenceEnabled: true, status: status)

        #expect(isOn == false)
    }

    @Test(arguments: [UNAuthorizationStatus.authorized, .provisional])
    func whenPreferenceDisabled_thenToggleStaysOffRegardlessOfAuthorization(_ status: UNAuthorizationStatus) {
        let isOn = makeEffectiveState(preferenceEnabled: false, status: status)

        #expect(isOn == false)
    }

    @Test
    func whenStatusIsUnknown_thenToggleIsOff() {
        let unknownStatus = UNAuthorizationStatus(rawValue: Int.max) ?? .notDetermined

        let isOn = makeEffectiveState(preferenceEnabled: true, status: unknownStatus)

        #expect(isOn == false)
    }

    @Test
    func whenCheckingAuthorizationHelper_thenReturnsTrueOnlyForAllowedStatuses() {
        #expect(NotificationToggleLogic.isAuthorized(for: .authorized))
        #expect(NotificationToggleLogic.isAuthorized(for: .provisional))
        #expect(NotificationToggleLogic.isAuthorized(for: .ephemeral))

        #expect(NotificationToggleLogic.isAuthorized(for: .denied) == false)
        #expect(NotificationToggleLogic.isAuthorized(for: .notDetermined) == false)
    }
}

// MARK: - makeSUT

private func makeEffectiveState(preferenceEnabled: Bool, status: UNAuthorizationStatus) -> Bool {
    NotificationToggleLogic.effectiveState(preferenceEnabled: preferenceEnabled, authorizationStatus: status)
}
