//  Created by Jiri Urbasek on 12/28/25.

import Foundation
import Testing
@testable import Billo

@MainActor
@Suite("AppFlowModel")
struct AppFlowModelTests {
    @Test func whenCompletingOnboarding_thenPersistsFlag() throws {
        let (sut, defaults) = makeSUT()

        sut.completeOnboarding()

        let persisted = AppPersistence(defaults: defaults).didCompleteOnboarding
        #expect(persisted)
    }

    @Test func whenMarkingPaywallShown_thenPersistsFlag() throws {
        let (sut, defaults) = makeSUT()

        sut.markFirstLaunchPaywallShown()

        let persisted = AppPersistence(defaults: defaults).didShowFirstLaunchPaywall
        #expect(persisted)
    }

    @Test func whenMarkingRatingPrompted_thenPersistsFlag() throws {
        let (sut, defaults) = makeSUT()

        sut.markRatingPrompted()

        let persisted = AppPersistence(defaults: defaults).didAskForRating
        #expect(persisted)
    }

    private func makeSUT() -> (AppFlowModel, UserDefaults) {
        let suiteName = "tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        let persistence = AppPersistence(defaults: defaults)
        return (AppFlowModel(persistence: persistence), defaults)
    }
}
