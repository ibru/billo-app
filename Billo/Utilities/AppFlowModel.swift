//  Created by Jiri Urbasek on 12/28/25.

import Observation

@Observable
final class AppFlowModel {
    private var persistence: AppPersistence

    var didCompleteOnboarding: Bool {
        didSet { persistence.didCompleteOnboarding = didCompleteOnboarding }
    }

    var didShowFirstLaunchPaywall: Bool {
        didSet { persistence.didShowFirstLaunchPaywall = didShowFirstLaunchPaywall }
    }

    var didAskForRating: Bool {
        didSet { persistence.didAskForRating = didAskForRating }
    }

    init(persistence: AppPersistence = AppPersistence()) {
        self.persistence = persistence
        self.didCompleteOnboarding = persistence.didCompleteOnboarding
        self.didShowFirstLaunchPaywall = persistence.didShowFirstLaunchPaywall
        self.didAskForRating = persistence.didAskForRating
    }

    func completeOnboarding() {
        didCompleteOnboarding = true
    }

    func markFirstLaunchPaywallShown() {
        didShowFirstLaunchPaywall = true
    }

    func markRatingPrompted() {
        didAskForRating = true
    }
}

