//  Created by Jiri Urbasek on 7/15/26.

import Foundation
import Testing
@testable import Billo

@MainActor
@Suite("ReviewPromptModel")
struct ReviewPromptModelTests {

    @MainActor
    @Suite("purchase triggers")
    struct PurchaseTriggers {
        @Test func whenPaywallPurchaseCompleted_thenRequestsReview() {
            let (sut, _, _) = makeSUT()

            #expect(sut.notePaywallPurchaseCompleted())
        }

        @Test func whenOnboardingPurchaseCompleted_thenRequestsReview() {
            let (sut, _, _) = makeSUT()

            #expect(sut.noteOnboardingPurchaseCompleted())
        }
    }

    @MainActor
    @Suite("caught-up payment")
    struct CaughtUpPayment {
        @Test func whenFewerPaymentsThanMinimumRecorded_thenCaughtUpDoesNotRequest() {
            let (sut, _, _) = makeSUT()

            let earlyResults = (1..<ReviewPromptModel.caughtUpMinimumPayments).map { _ in
                sut.notePaymentRecorded(isCaughtUp: true)
            }

            #expect(earlyResults.allSatisfy { $0 == false })
        }

        @Test func whenMinimumPaymentsReachedAndCaughtUp_thenRequestsReview() {
            let (sut, _, _) = makeSUT()
            recordPayments(on: sut, count: ReviewPromptModel.caughtUpMinimumPayments - 1)

            #expect(sut.notePaymentRecorded(isCaughtUp: true))
        }

        @Test func whenMinimumPaymentsReachedButNotCaughtUp_thenDoesNotRequest() {
            let (sut, _, _) = makeSUT()
            recordPayments(on: sut, count: ReviewPromptModel.caughtUpMinimumPayments - 1)

            #expect(sut.notePaymentRecorded(isCaughtUp: false) == false)
        }

        @Test func whenEarlierPaymentsWereNotCaughtUp_thenTheyStillCountTowardMinimum() {
            let (sut, _, _) = makeSUT()
            for _ in 1..<ReviewPromptModel.caughtUpMinimumPayments {
                _ = sut.notePaymentRecorded(isCaughtUp: false)
            }

            #expect(sut.notePaymentRecorded(isCaughtUp: true))
        }

        @Test func whenCaughtUpRepeatedly_thenRequestsEveryTime() {
            // Pacing is deliberately iOS's job (3 displays per 365 days);
            // the model requests on every quality moment.
            let (sut, _, _) = makeSUT()
            recordPayments(on: sut, count: ReviewPromptModel.caughtUpMinimumPayments - 1)

            let thirdPayment = sut.notePaymentRecorded(isCaughtUp: true)
            let fourthPayment = sut.notePaymentRecorded(isCaughtUp: true)

            #expect(thirdPayment && fourthPayment)
        }

        @Test func whenPaymentsRecordedAcrossInstances_thenCountPersists() {
            let (sut, _, defaults) = makeSUT()
            recordPayments(on: sut, count: ReviewPromptModel.caughtUpMinimumPayments - 1)

            let (freshInstance, _, _) = makeSUT(defaults: defaults)

            #expect(freshInstance.notePaymentRecorded(isCaughtUp: true))
        }
    }

    @MainActor
    @Suite("bill milestone")
    struct BillMilestone {
        @Test func whenBillCountBelowMilestone_thenDoesNotRequest() {
            let (sut, _, _) = makeSUT()

            let result = sut.noteBillSaved(totalBillCount: ReviewPromptModel.billMilestoneCount - 1)

            #expect(result == false)
        }

        @Test func whenBillCountReachesMilestone_thenRequestsReview() {
            let (sut, _, _) = makeSUT()

            #expect(sut.noteBillSaved(totalBillCount: ReviewPromptModel.billMilestoneCount))
        }

        @Test func whenMilestoneAlreadyRequested_thenNeverRequestsAgain() {
            let (sut, _, _) = makeSUT()
            #expect(sut.noteBillSaved(totalBillCount: ReviewPromptModel.billMilestoneCount))

            let result = sut.noteBillSaved(totalBillCount: ReviewPromptModel.billMilestoneCount + 1)

            #expect(result == false)
        }

        @Test func whenMilestoneRequestedOnPreviousInstance_thenFreshInstanceNeverRequestsAgain() {
            let (sut, _, defaults) = makeSUT()
            #expect(sut.noteBillSaved(totalBillCount: ReviewPromptModel.billMilestoneCount))

            let (freshInstance, _, _) = makeSUT(defaults: defaults)

            #expect(freshInstance.noteBillSaved(totalBillCount: ReviewPromptModel.billMilestoneCount + 1) == false)
        }
    }

    @MainActor
    @Suite("income milestone")
    struct IncomeMilestone {
        @Test func whenIncomeCountBelowMilestone_thenDoesNotRequest() {
            let (sut, _, _) = makeSUT()

            let result = sut.noteIncomeSaved(totalIncomeCount: ReviewPromptModel.incomeMilestoneCount - 1)

            #expect(result == false)
        }

        @Test func whenIncomeCountReachesMilestone_thenRequestsReview() {
            let (sut, _, _) = makeSUT()

            #expect(sut.noteIncomeSaved(totalIncomeCount: ReviewPromptModel.incomeMilestoneCount))
        }

        @Test func whenMilestoneAlreadyRequested_thenNeverRequestsAgain() {
            let (sut, _, _) = makeSUT()
            #expect(sut.noteIncomeSaved(totalIncomeCount: ReviewPromptModel.incomeMilestoneCount))

            let result = sut.noteIncomeSaved(totalIncomeCount: ReviewPromptModel.incomeMilestoneCount)

            #expect(result == false)
        }

        @Test func whenMilestoneRequestedOnPreviousInstance_thenFreshInstanceNeverRequestsAgain() {
            let (sut, _, defaults) = makeSUT()
            #expect(sut.noteIncomeSaved(totalIncomeCount: ReviewPromptModel.incomeMilestoneCount))

            let (freshInstance, _, _) = makeSUT(defaults: defaults)

            #expect(freshInstance.noteIncomeSaved(totalIncomeCount: ReviewPromptModel.incomeMilestoneCount) == false)
        }
    }

    @MainActor
    @Suite("disabled model")
    struct DisabledModel {
        @Test func whenDisabled_thenNoTriggerRequestsAndNothingIsCaptured() {
            // SCREENSHOTS builds: the rating dialog must never pop mid-capture.
            let (sut, analytics, _) = makeSUT(isEnabled: false)

            let results = [
                sut.notePaywallPurchaseCompleted(),
                sut.noteOnboardingPurchaseCompleted(),
                sut.notePaymentRecorded(isCaughtUp: true),
                sut.noteBillSaved(totalBillCount: ReviewPromptModel.billMilestoneCount),
                sut.noteIncomeSaved(totalIncomeCount: ReviewPromptModel.incomeMilestoneCount)
            ]

            #expect(results.allSatisfy { $0 == false } && analytics.capturedEvents.isEmpty)
        }
    }

    @MainActor
    @Suite("analytics")
    struct Analytics {
        @Test func whenEachTriggerRequests_thenCapturesItsTriggerDimension() {
            let (sut, analytics, _) = makeSUT()

            _ = sut.noteOnboardingPurchaseCompleted()
            _ = sut.notePaywallPurchaseCompleted()
            recordPayments(on: sut, count: ReviewPromptModel.caughtUpMinimumPayments)
            _ = sut.noteBillSaved(totalBillCount: ReviewPromptModel.billMilestoneCount)
            _ = sut.noteIncomeSaved(totalIncomeCount: ReviewPromptModel.incomeMilestoneCount)

            #expect(analytics.capturedEvents.allSatisfy { $0.name == "rating prompt requested" })
            #expect(analytics.capturedEvents.map { $0.properties["trigger"] as? String } == [
                "onboarding_purchase", "paywall_purchase", "caught_up", "bill_milestone", "income_milestone"
            ])
        }

        @Test func whenTriggerDeclined_thenCapturesNothing() {
            let (sut, analytics, _) = makeSUT()

            _ = sut.notePaymentRecorded(isCaughtUp: true)

            #expect(analytics.capturedEvents.isEmpty)
        }

        @Test func whenEnumeratingTriggers_thenRawValuesMatchAnalyticsContract() {
            // The `trigger` property joins PostHog funnels — raw values must
            // never drift once shipped.
            #expect(ReviewPromptTrigger.allCases.map(\.rawValue) == [
                "onboarding_purchase", "paywall_purchase", "caught_up", "bill_milestone", "income_milestone"
            ])
        }
    }
}

// MARK: - makeSUT & Factories

@MainActor
private func makeSUT(
    defaults: UserDefaults? = nil,
    isEnabled: Bool = true
) -> (sut: ReviewPromptModel, analytics: AnalyticsEventsSpy, defaults: UserDefaults) {
    let resolvedDefaults = defaults ?? makeCleanDefaults()
    let analytics = AnalyticsEventsSpy()
    let sut = ReviewPromptModel(
        persistence: AppPersistence(defaults: resolvedDefaults),
        isEnabled: isEnabled,
        analyticsCapture: { analytics.capture($0) }
    )
    return (sut, analytics, resolvedDefaults)
}

private func makeCleanDefaults() -> UserDefaults {
    let suiteName = "tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

@MainActor
private func recordPayments(on sut: ReviewPromptModel, count: Int) {
    for _ in 0..<count {
        _ = sut.notePaymentRecorded(isCaughtUp: true)
    }
}

// MARK: - Test Doubles

@MainActor
private final class AnalyticsEventsSpy {
    private(set) var capturedEvents: [AnalyticsEvent] = []

    func capture(_ event: AnalyticsEvent) {
        capturedEvents.append(event)
    }
}
