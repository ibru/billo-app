//  Created by Jiri Urbasek on 7/11/26.

import SwiftUI

/// Empathy screen: absolves the user ("it's the system, not you"), normalizes
/// the problem with a trust card, and bridges into the feature screens that
/// follow ("let us show you"). Two trust-card variants are being evaluated:
/// a research stat (authority) vs. a user-voice quote (peer relatability).
struct OnboardingEmpathyStepView: View {
    enum TrustCard {
        case stat
        case quote
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let trustCard: TrustCard
    let progressIndex: Int?
    let onContinue: () -> Void

    var body: some View {
        OnboardingStepContainer(
            progressIndex: progressIndex,
            primaryTitle: "Show me how",
            onPrimary: onContinue
        ) {
            VStack(spacing: DesignSystem.Spacing.extraLarge) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.pulse, isActive: !reduceMotion)
                    .accessibilityHidden(true)
                    .padding(.top, DesignSystem.Spacing.large)

                VStack(spacing: DesignSystem.Spacing.small) {
                    Text("It’s not you — it’s the system", comment: "Onboarding empathy title")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text(
                        "Nobody can hold a dozen due dates in their head. Missed bills aren’t a discipline problem — they’re a visibility problem.",
                        comment: "Onboarding empathy subtitle"
                    )
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }

                trustCardView

                // The pivot from "you're understood" to "here comes the fix" —
                // deliberately loud so nobody misses that the solution starts
                // on the next screen.
                VStack(spacing: DesignSystem.Spacing.small) {
                    Text(
                        "Let’s see how Billo takes this off your mind",
                        comment: "Onboarding empathy bridge line into the feature screens"
                    )
                    .font(.title3.bold())
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.center)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.tint)
                        .symbolEffect(.bounce, options: .repeat(.periodic(delay: 1.5)), isActive: !reduceMotion)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var trustCardView: some View {
        switch trustCard {
        case .stat:
            card(
                symbol: "chart.bar.fill",
                body: Text(
                    "Bills are the #1 money worry — 49% of people rank them as their top financial anxiety.",
                    comment: "Onboarding empathy research stat"
                ),
                source: Text("Motley Fool, 2024", comment: "Onboarding empathy stat source")
            )
        case .quote:
            card(
                symbol: "quote.opening",
                body: Text(
                    "“I’m tired of feeling behind. I just want to know what’s due next.”",
                    comment: "Onboarding empathy user-voice quote"
                ),
                source: Text("a bill-tracker app review", comment: "Onboarding empathy quote source")
            )
        }
    }

    private func card(symbol: String, body: Text, source: Text) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.mediumSmall) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                body
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)

                (Text("— ") + source)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignSystem.Spacing.medium)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .cardShadow()
        .frame(maxWidth: 360)
    }
}

#if DEBUG
#Preview("Stat card") {
    OnboardingEmpathyStepView(
        trustCard: .stat,
        progressIndex: OnboardingStep.empathyStat.progressIndex,
        onContinue: {}
    )
    .tint(DesignSystem.Color.green)
}

#Preview("Quote card") {
    OnboardingEmpathyStepView(
        trustCard: .quote,
        progressIndex: OnboardingStep.empathyQuote.progressIndex,
        onContinue: {}
    )
    .tint(DesignSystem.Color.green)
}
#endif
