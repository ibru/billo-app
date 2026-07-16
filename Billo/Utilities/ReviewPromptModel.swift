//  Created by Jiri Urbasek on 7/15/26.

import Foundation
import Observation

/// The pleasant moment that earned a review request. Raw values ship as the
/// `trigger` property of the `rating prompt requested` analytics event.
enum ReviewPromptTrigger: String, Sendable, CaseIterable {
    case onboardingPurchase = "onboarding_purchase"
    case paywallPurchase = "paywall_purchase"
    case caughtUp = "caught_up"
    case billMilestone = "bill_milestone"
    case incomeMilestone = "income_milestone"
}

/// Single decision point for `requestReview` triggers. There is deliberately
/// NO time-based cooldown here: iOS itself limits the rating dialog to 3
/// displays per 365 days and silently ignores excess requests, so pacing is
/// the system's job. This model only guards moment *quality* — a maturity
/// minimum before the caught-up ask, and once-only milestone flags.
///
/// State is local-only UserDefaults (not CloudKit-synced), consistent with
/// `didAskForRating`; a reinstall resetting the counters is accepted.
///
/// `@Observable` carries no observed state here (every stored property is
/// `@ObservationIgnored`) — it exists solely so the model can be injected via
/// `.environment(_:)`.
@Observable
final class ReviewPromptModel {
    /// The caught-up trigger stays quiet until the user has recorded this many
    /// payments — brand-new users shouldn't be asked before feeling real value.
    static let caughtUpMinimumPayments = 3
    static let billMilestoneCount = 10
    static let incomeMilestoneCount = 2

    @ObservationIgnored private let persistence: AppPersistence
    @ObservationIgnored private let analyticsCapture: (AnalyticsEvent) -> Void
    /// False in SCREENSHOTS builds: the system rating dialog must never pop
    /// over a capture. Disabled means every trigger declines silently.
    @ObservationIgnored private let isEnabled: Bool

    init(
        persistence: AppPersistence = AppPersistence(),
        isEnabled: Bool = true,
        analyticsCapture: @escaping (AnalyticsEvent) -> Void = { _ in }
    ) {
        self.persistence = persistence
        self.isEnabled = isEnabled
        self.analyticsCapture = analyticsCapture
    }

    // MARK: - Trigger events
    // Bool-returning events tell the caller whether to present the system
    // rating dialog now; analytics are recorded internally.

    /// A Pro purchase completed on an in-app paywall (feature gate or
    /// Settings). Always worth an ask — the system decides whether to show.
    func notePaywallPurchaseCompleted() -> Bool {
        guard isEnabled else { return false }
        recordRequest(.paywallPurchase)
        return true
    }

    /// A payment was recorded from a UI surface. `isCaughtUp` is the domain
    /// fact "nothing *visible* is due today or overdue" (`BillsModel.isCaughtUp`
    /// — the free-tier display cap applies, per the visible-set architecture
    /// rule) supplied by the caller so this model stays free of bill semantics.
    /// Deliberate: pre-paying a future occurrence while already caught up
    /// counts — a diligent early-payer is still a satisfied user.
    func notePaymentRecorded(isCaughtUp: Bool) -> Bool {
        guard isEnabled else { return false }
        persistence.recordedPaymentCount += 1
        guard persistence.recordedPaymentCount >= Self.caughtUpMinimumPayments,
              isCaughtUp
        else { return false }
        recordRequest(.caughtUp)
        return true
    }

    /// A bill was saved from the in-app editor. Fires at most once, on any
    /// save at-or-above the milestone (not strictly the crossing — accepted:
    /// the app ships with this feature, so no legacy over-milestone cohort
    /// exists).
    func noteBillSaved(totalBillCount: Int) -> Bool {
        guard isEnabled,
              totalBillCount >= Self.billMilestoneCount,
              persistence.didRequestBillMilestoneReview == false
        else { return false }
        persistence.didRequestBillMilestoneReview = true
        recordRequest(.billMilestone)
        return true
    }

    /// An income was saved from the in-app editor. Same once-only semantics
    /// as the bill milestone.
    func noteIncomeSaved(totalIncomeCount: Int) -> Bool {
        guard isEnabled,
              totalIncomeCount >= Self.incomeMilestoneCount,
              persistence.didRequestIncomeMilestoneReview == false
        else { return false }
        persistence.didRequestIncomeMilestoneReview = true
        recordRequest(.incomeMilestone)
        return true
    }

    /// The onboarding thank-you screen keeps its own once-ever guard
    /// (`AppFlowModel.didAskForRating` — the opportunity is consumed whether
    /// or not the system shows the dialog); it reports here so the prompt
    /// carries the trigger dimension in analytics.
    func noteOnboardingPurchaseCompleted() -> Bool {
        guard isEnabled else { return false }
        recordRequest(.onboardingPurchase)
        return true
    }

    private func recordRequest(_ trigger: ReviewPromptTrigger) {
        Logger.log("Rating prompt requested (trigger: \(trigger.rawValue))", level: .info)
        analyticsCapture(.ratingPromptRequested(trigger: trigger))
    }
}
