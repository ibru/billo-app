//  Created by Jiri Urbasek on 12/28/25.

import StoreKit
import SwiftUI

struct PurchaseThankYouView: View {
    @Environment(\.requestReview) private var requestReview
    @Environment(AppFlowModel.self) private var flow
    @Environment(ReviewPromptModel.self) private var reviewPrompts

    let onContinue: () -> Void

    @State private var showContent: Bool = false
    @State private var didTriggerReview: Bool = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            Spacer()

            Image(systemName: "crown.fill")
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(showContent ? 1 : 0.6)
                .opacity(showContent ? 1 : 0)
                .accessibilityHidden(true)

            VStack(spacing: DesignSystem.Spacing.small) {
                Text("Thanks for going Pro")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 12)

                Text("You’re set up for a calmer, more predictable billing routine.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 12)
            }
            .padding(.horizontal, DesignSystem.Spacing.large)

            VStack(spacing: DesignSystem.Spacing.medium) {
                ThankYouBenefitRow(icon: "calendar.badge.clock", text: "See what’s due next")
                ThankYouBenefitRow(icon: "checkmark.circle", text: "Track what’s already paid")
                ThankYouBenefitRow(icon: "bell", text: "Stay ahead of late fees")
            }
            .padding(.horizontal, DesignSystem.Spacing.large)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 12)

            Spacer()

            Button {
                Logger.log("Thank-you continue tapped", level: .info)
                onContinue()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding(.horizontal, DesignSystem.Spacing.large)
            .padding(.bottom, DesignSystem.Spacing.large)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 16)
            .accessibilityIdentifier("thank_you_continue")
        }
        .background(DesignSystem.Color.background.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(duration: 0.6)) {
                showContent = true
            }
        }
        .task {
            // Abort on cancellation (user tapped Continue within the delay) —
            // firing the dialog mid-navigation is worse than skipping it.
            guard (try? await Task.sleep(for: .seconds(1))) != nil else { return }
            triggerRatingIfNeeded()
        }
    }

    private func triggerRatingIfNeeded() {
        guard didTriggerReview == false else { return }
        guard flow.didAskForRating == false else { return }

        didTriggerReview = true
        flow.markRatingPrompted()
        // Captures the analytics event (trigger: onboarding_purchase);
        // false only when review prompts are disabled (SCREENSHOTS).
        if reviewPrompts.noteOnboardingPurchaseCompleted() {
            requestReview()
        }
    }
}

private struct ThankYouBenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(text)
                .font(.body.weight(.medium))

            Spacer()
        }
        .padding(DesignSystem.Spacing.medium)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}

#if DEBUG && targetEnvironment(simulator)
#Preview {
    // Unique suite per render: this preview auto-fires the rating flow after
    // 1 s — a fixed suite would persist `didAskForRating` and the prompt
    // counters on the dev machine, making every later render skip the flow.
    let previewDefaults = UserDefaults(suiteName: "preview-thanks-\(UUID().uuidString)") ?? .standard
    let flow = AppFlowModel(persistence: AppPersistence(defaults: previewDefaults))
    return PurchaseThankYouView(onContinue: {})
        .environment(flow)
        .environment(ReviewPromptModel(persistence: AppPersistence(defaults: previewDefaults)))
}
#endif
