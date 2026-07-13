//  Created by Jiri Urbasek on 7/10/26.

import Foundation
import Testing
@testable import Billo

@Suite("ReturningUserSkipPolicy")
struct ReturningUserSkipPolicyTests {
    @Test func whenSyncedBillsArriveMidFlow_thenOnboardingIsSkipped() {
        #expect(shouldSkip(hasSyncedBills: true) == true)
    }

    @Test func whenSyncedCurrencyArrivesAndUserDidNotPickCurrencyHere_thenOnboardingIsSkipped() {
        #expect(shouldSkip(hasSyncedCurrency: true) == true)
    }

    @Test func whenCurrencyWasPickedLocally_thenCurrencySignalAloneDoesNotSkip() {
        #expect(shouldSkip(hasSyncedCurrency: true, didSetCurrencyLocally: true) == false)
    }

    @Test func whenCurrencyWasPickedLocallyButSyncedBillsArrive_thenOnboardingIsSkipped() {
        #expect(shouldSkip(hasSyncedBills: true, hasSyncedCurrency: true, didSetCurrencyLocally: true) == true)
    }

    @Test func whenThisFlowAlreadyCommittedItsOwnSetup_thenOwnBillsNeverTriggerSkip() {
        #expect(shouldSkip(hasSyncedBills: true, hasSyncedCurrency: true, didSetCurrencyLocally: true, didCommitLocalSetup: true) == false)
    }

    @Test func whenUserIsOnPurchaseScreens_thenSkipIsSuppressed() {
        #expect(shouldSkip(hasSyncedBills: true, currentStep: .paywall) == false)
        #expect(shouldSkip(hasSyncedBills: true, currentStep: .thankYou) == false)
    }

    @Test func whenSyncedBillsArriveOnAnyNonPurchaseStep_thenOnboardingIsSkipped() {
        let nonPurchaseSteps = OnboardingStep.activeFlowSteps.filter { $0 != .paywall }
        for step in nonPurchaseSteps {
            #expect(shouldSkip(hasSyncedBills: true, currentStep: step) == true)
        }
    }

    @Test func whenNoSyncedDataExists_thenOnboardingContinues() {
        #expect(shouldSkip() == false)
    }
}

// MARK: - makeSUT & Factories

private func shouldSkip(
    hasSyncedBills: Bool = false,
    hasSyncedCurrency: Bool = false,
    didSetCurrencyLocally: Bool = false,
    didCommitLocalSetup: Bool = false,
    currentStep: OnboardingStep = .painBubbles
) -> Bool {
    ReturningUserSkipPolicy().shouldSkipOnboarding(
        hasSyncedBills: hasSyncedBills,
        hasSyncedCurrency: hasSyncedCurrency,
        didSetCurrencyLocally: didSetCurrencyLocally,
        didCommitLocalSetup: didCommitLocalSetup,
        currentStep: currentStep
    )
}
