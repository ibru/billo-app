//  Created by Jiri Urbasek on 12/28/25.

import Foundation

struct AppPersistence {
    private enum Key {
        static let didCompleteOnboarding = "didCompleteOnboarding"
        static let didShowFirstLaunchPaywall = "didShowFirstLaunchPaywall"
        static let didAskForRating = "didAskForRating"
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

#if DEBUG
    nonmutating func resetAll() {
        defaults.removeObject(forKey: Key.didCompleteOnboarding)
        defaults.removeObject(forKey: Key.didShowFirstLaunchPaywall)
        defaults.removeObject(forKey: Key.didAskForRating)
    }
#endif
}

