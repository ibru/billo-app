//  Created by Jiri Urbasek on 12/28/25.

import Testing
@testable import Billo

@Suite("FirstLaunchPaywallPolicy")
struct FirstLaunchPaywallPolicyTests {
    @Test func whenUserAlreadyPro_thenDoesNotShowPaywall() async throws {
        let sut = FirstLaunchPaywallPolicy()

        #expect(sut.shouldShowPaywallAfterOnboarding(entitlementIsPro: true, didShowFirstLaunchPaywall: false) == false)
    }

    @Test func whenPaywallAlreadyShown_thenDoesNotShowPaywall() async throws {
        let sut = FirstLaunchPaywallPolicy()

        #expect(sut.shouldShowPaywallAfterOnboarding(entitlementIsPro: false, didShowFirstLaunchPaywall: true) == false)
    }

    @Test func whenNotProAndPaywallNotShown_thenShowsPaywall() async throws {
        let sut = FirstLaunchPaywallPolicy()

        #expect(sut.shouldShowPaywallAfterOnboarding(entitlementIsPro: false, didShowFirstLaunchPaywall: false))
    }
}

