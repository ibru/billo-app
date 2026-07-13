//  Created by Jiri Urbasek on 7/12/26.

import SwiftUI

/// Transition from the explanation screens into the setup ones: a promise
/// callback to the pain screen ("bills you keep in your head" → "let's get
/// them out of your head") framed as the moment momentum starts.
struct OnboardingSetupIntroStepView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onContinue: () -> Void

    var body: some View {
        OnboardingStepContainer(
            progressIndex: OnboardingStep.setupIntro.progressIndex,
            primaryTitle: "Let’s do it",
            onPrimary: onContinue
        ) {
            VStack(spacing: DesignSystem.Spacing.extraLarge) {
                // SF Symbols has no rocket; the trophy carries the "you'll
                // win at this" promise instead.
                Image(systemName: "trophy.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .repeat(.periodic(delay: 2.0)), isActive: !reduceMotion)
                    .frame(width: 96, height: 96)
                    .background(DesignSystem.Color.green.gradient, in: Circle())
                    .cardShadow()
                    .accessibilityHidden(true)
                    .padding(.top, DesignSystem.Spacing.large)

                VStack(spacing: DesignSystem.Spacing.small) {
                    Text("Let’s get bills out of your head", comment: "Onboarding setup intro title")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text(
                        "Two minutes of setup — then Billo takes over the remembering.",
                        comment: "Onboarding setup intro subtitle"
                    )
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#if DEBUG
#Preview {
    OnboardingSetupIntroStepView(onContinue: {})
        .tint(DesignSystem.Color.green)
}
#endif
