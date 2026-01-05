//  Created by Jiri Urbasek on 12/29/25.

import SwiftUI

struct FirstLaunchMarketingStepTemplateView: View {
    let systemImage: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let continueTitle: LocalizedStringKey
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: DesignSystem.Spacing.large) {
                Image(systemName: systemImage)
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)

                VStack(spacing: DesignSystem.Spacing.small) {
                    Text(title)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DesignSystem.Spacing.extraLarge)
            }

            Spacer(minLength: 0)

            Button {
                onContinue()
            } label: {
                Text(continueTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding(.horizontal, DesignSystem.Spacing.large)
            .padding(.bottom, DesignSystem.Spacing.large)
            .accessibilityIdentifier("onboarding_continue")
        }
        .background(DesignSystem.Color.background.ignoresSafeArea())
    }
}
