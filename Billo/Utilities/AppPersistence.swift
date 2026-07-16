//  Created by Jiri Urbasek on 12/28/25.

import Foundation

struct AppPersistence {
    private enum Key {
        static let didCompleteOnboarding = "didCompleteOnboarding"
        static let didShowFirstLaunchPaywall = "didShowFirstLaunchPaywall"
        static let didAskForRating = "didAskForRating"
        static let recordedPaymentCount = "recordedPaymentCount"
        static let didRequestBillMilestoneReview = "didRequestBillMilestoneReview"
        static let didRequestIncomeMilestoneReview = "didRequestIncomeMilestoneReview"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var didCompleteOnboarding: Bool {
        get { defaults.bool(forKey: Key.didCompleteOnboarding) }
        nonmutating set { defaults.set(newValue, forKey: Key.didCompleteOnboarding) }
    }

    var didShowFirstLaunchPaywall: Bool {
        get { defaults.bool(forKey: Key.didShowFirstLaunchPaywall) }
        nonmutating set { defaults.set(newValue, forKey: Key.didShowFirstLaunchPaywall) }
    }

    var didAskForRating: Bool {
        get { defaults.bool(forKey: Key.didAskForRating) }
        nonmutating set { defaults.set(newValue, forKey: Key.didAskForRating) }
    }

    /// Lifetime count of UI-recorded payments — the "user maturity" gate for
    /// the caught-up review trigger.
    var recordedPaymentCount: Int {
        get { defaults.integer(forKey: Key.recordedPaymentCount) }
        nonmutating set { defaults.set(newValue, forKey: Key.recordedPaymentCount) }
    }

    var didRequestBillMilestoneReview: Bool {
        get { defaults.bool(forKey: Key.didRequestBillMilestoneReview) }
        nonmutating set { defaults.set(newValue, forKey: Key.didRequestBillMilestoneReview) }
    }

    var didRequestIncomeMilestoneReview: Bool {
        get { defaults.bool(forKey: Key.didRequestIncomeMilestoneReview) }
        nonmutating set { defaults.set(newValue, forKey: Key.didRequestIncomeMilestoneReview) }
    }

#if DEBUG
    nonmutating func resetAll() {
        defaults.removeObject(forKey: Key.didCompleteOnboarding)
        defaults.removeObject(forKey: Key.didShowFirstLaunchPaywall)
        defaults.removeObject(forKey: Key.didAskForRating)
        defaults.removeObject(forKey: Key.recordedPaymentCount)
        defaults.removeObject(forKey: Key.didRequestBillMilestoneReview)
        defaults.removeObject(forKey: Key.didRequestIncomeMilestoneReview)
    }
#endif
}

