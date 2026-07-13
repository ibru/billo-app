//  Created by Jiri Urbasek on 7/10/26.

import Foundation

/// Semantic steps of the first-launch onboarding flow. Order is defined by
/// `activeFlowSteps` (not declaration order) so reordering the flow is a
/// one-line edit. `thankYou` is intentionally off-array: it is pushed only
/// after a successful purchase.
nonisolated enum OnboardingStep: String, Hashable, CaseIterable {
    // TEMPORARY A/B evaluation: the old `hook` step is being split into a
    // pain screen + an empathy screen. Both visual variants of each are in
    // the flow side by side so the winner can be picked on device; afterwards
    // collapse these four into final `pain` and `empathy` cases.
    case painBubbles = "pain_bubbles"
    case painScattered = "pain_scattered"
    case empathyStat = "empathy_stat"
    case empathyQuote = "empathy_quote"
    case viewModes = "view_modes"
    case incomeNet = "income_net"
    case reminders
    case currency
    case billSetup = "bill_setup"
    case income
    case setupIntro = "setup_intro"
    case notifications
    case paywall
    case thankYou = "thank_you"

    /// The single source of truth for flow order. Reorder/add/remove here to
    /// change the onboarding flow.
    static let activeFlowSteps: [OnboardingStep] = [
        .painBubbles,
//        .painScattered,
        .empathyStat,
//        .empathyQuote,
        .viewModes,
        .incomeNet,
        .reminders,
        .setupIntro,
        .currency,
        .billSetup,
        .income,
        .notifications,
        // Paywall removed from onboarding for now — restore by uncommenting
        // here and in OnboardingFlowView.evaluatePaywall().
//        .paywall,
    ]

    /// Steps counted by the progress bar. The paywall is deliberately excluded —
    /// it should feel like the flow is already over, not like one more hurdle.
    static let progressSteps: [OnboardingStep] = activeFlowSteps.filter { $0 != .paywall }

    static var progressTotal: Int { progressSteps.count }

    static func next(after step: OnboardingStep) -> OnboardingStep? {
        guard let index = activeFlowSteps.firstIndex(of: step) else { return nil }
        let nextIndex = index + 1
        guard activeFlowSteps.indices.contains(nextIndex) else { return nil }
        return activeFlowSteps[nextIndex]
    }

    /// Zero-based position in the progress bar, or nil for steps that don't
    /// show progress (paywall, thankYou).
    var progressIndex: Int? {
        Self.progressSteps.firstIndex(of: self)
    }

    /// Snake_case value for the `step` property of analytics events.
    var analyticsName: String { rawValue }
}
