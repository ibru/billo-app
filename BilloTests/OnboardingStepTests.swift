//  Created by Jiri Urbasek on 7/10/26.

import Foundation
import Testing
@testable import Billo

@Suite("OnboardingStep")
struct OnboardingStepTests {
    @Test func whenFlowStarts_thenFirstStepIsPain() {
        #expect(OnboardingStep.activeFlowSteps.first == .painBubbles)
    }

    // Chosen variants: pain = thought bubbles, empathy = stat card. The
    // losing variant cases still exist on OnboardingStep pending cleanup.
    @Test func whenAdvancingThroughFlow_thenStepsFollowApprovedOrder() {
        #expect(OnboardingStep.activeFlowSteps == [
            .painBubbles, .empathyStat,
            .viewModes, .incomeNet, .reminders,
            // Paywall currently removed from onboarding (commented out in
            // activeFlowSteps).
            .setupIntro, .currency, .billSetup, .income, .notifications,
        ])
    }

    @Test func whenAdvancingFromEachStep_thenNextFollowsFlowOrder() {
        let steps = OnboardingStep.activeFlowSteps
        for (index, step) in steps.enumerated() {
            let expectedNext = index + 1 < steps.count ? steps[index + 1] : nil
            #expect(OnboardingStep.next(after: step) == expectedNext)
        }
    }

    @Test func whenAdvancingPastPaywall_thenFlowEnds() {
        #expect(OnboardingStep.next(after: .paywall) == nil)
    }

    @Test func whenAdvancingFromThankYou_thenThereIsNoNextStep() {
        #expect(OnboardingStep.next(after: .thankYou) == nil)
    }

    @Test func whenShowingProgress_thenPaywallAndThankYouAreExcluded() {
        #expect(OnboardingStep.paywall.progressIndex == nil)
        #expect(OnboardingStep.thankYou.progressIndex == nil)
        #expect(OnboardingStep.progressTotal == 10)
    }

    @Test func whenShowingProgress_thenActiveStepsCountUpSequentially() {
        let indices = OnboardingStep.progressSteps.map(\.progressIndex)
        #expect(indices == Array(0..<OnboardingStep.progressTotal).map { Optional($0) })
    }

    @Test func whenReportingAnalytics_thenStepNamesAreSnakeCase() {
        #expect(OnboardingStep.viewModes.analyticsName == "view_modes")
        #expect(OnboardingStep.incomeNet.analyticsName == "income_net")
        #expect(OnboardingStep.billSetup.analyticsName == "bill_setup")
        #expect(OnboardingStep.thankYou.analyticsName == "thank_you")
    }
}
