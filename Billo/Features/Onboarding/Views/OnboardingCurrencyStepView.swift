//  Created by Jiri Urbasek on 12/29/25.

import SwiftUI

struct OnboardingCurrencyStepView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let progressIndex = OnboardingStep.currency.progressIndex {
                OnboardingProgressBar(currentIndex: progressIndex, total: OnboardingStep.progressTotal)
                    .padding(.horizontal, DesignSystem.Spacing.large)
                    .frame(maxWidth: 560)
                    .padding(.top, DesignSystem.Spacing.medium)
            }

            // Advance on the explicit save callback, NOT by observing
            // `currencyCode` — a CloudKit-synced currency arriving while this
            // screen is up must not advance the flow as if the user picked it
            // (it should instead trigger the returning-user skip).
            CurrencyOnboardingView(onSaved: onContinue)
        }
        .background(DesignSystem.Color.background.ignoresSafeArea())
    }
}

#if DEBUG && targetEnvironment(simulator)
#Preview {
    let preview = BilloPreviewContainer.empty()
    return OnboardingCurrencyStepView(onContinue: {})
        .environment(preview.appSettingsModel)
        .environment(AnalyticsModel())
}
#endif
