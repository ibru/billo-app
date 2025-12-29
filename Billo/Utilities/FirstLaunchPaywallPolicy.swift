//  Created by Jiri Urbasek on 12/28/25.

struct FirstLaunchPaywallPolicy: Sendable {
    nonisolated func shouldShowPaywallAfterOnboarding(
        entitlementIsPro: Bool,
        didShowFirstLaunchPaywall: Bool
    ) -> Bool {
        guard entitlementIsPro == false else { return false }
        guard didShowFirstLaunchPaywall == false else { return false }
        return true
    }
}
