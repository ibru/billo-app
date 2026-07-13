//  Created by Jiri Urbasek on 7/10/26.

import SwiftUI

struct OnboardingRemindersStepView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onContinue: () -> Void

    @State private var visibleBanners = 0

    var body: some View {
        OnboardingStepContainer(
            progressIndex: OnboardingStep.reminders.progressIndex,
            primaryTitle: "Continue",
            onPrimary: onContinue
        ) {
            VStack(spacing: DesignSystem.Spacing.extraLarge) {
                VStack(spacing: DesignSystem.Spacing.mediumSmall) {
                    OnboardingNotificationBannerMock(
                        title: Text("Electricity due tomorrow", comment: "Onboarding mock notification title"),
                        message: Text("Reminder from Billo — one tap to mark it paid.", comment: "Onboarding mock notification body")
                    )
                    .opacity(visibleBanners >= 1 ? 1 : 0)
                    .offset(y: visibleBanners >= 1 ? 0 : -24)

                    OnboardingNotificationBannerMock(
                        title: Text("3 bills due this week", comment: "Onboarding mock notification title"),
                        message: Text("Your morning digest, so nothing sneaks up on you.", comment: "Onboarding mock notification body")
                    )
                    .opacity(visibleBanners >= 2 ? 1 : 0)
                    .offset(y: visibleBanners >= 2 ? 0 : -24)
                }
                .padding(.top, DesignSystem.Spacing.large)

                VStack(spacing: DesignSystem.Spacing.small) {
                    Text("Never miss a due date", comment: "Onboarding reminders title")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text(
                        "Billo reminds you before each bill is due — no more spreadsheets, email digging, or noisy calendar alerts.",
                        comment: "Onboarding reminders subtitle"
                    )
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .task {
            guard !reduceMotion else {
                visibleBanners = 2
                return
            }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.spring(duration: 0.6)) { visibleBanners = 1 }
            try? await Task.sleep(for: .milliseconds(800))
            withAnimation(.spring(duration: 0.6)) { visibleBanners = 2 }
        }
    }
}

/// A rounded card shaped like an iOS notification banner. Reused by the
/// notifications-permission step so the visual language matches.
struct OnboardingNotificationBannerMock: View {
    let title: Text
    let message: Text

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.medium) {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(DesignSystem.Color.green.gradient)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "checklist")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                HStack {
                    Text("Billo", comment: "App name shown in the mock notification banner")
                        .font(.footnote.weight(.semibold))
                    Spacer()
                    Text("now", comment: "Timestamp shown in the mock notification banner")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                title
                    .font(.subheadline.weight(.semibold))
                message
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(.background, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .strokeBorder(.separator, lineWidth: 1)
        }
        .cardShadow()
    }
}

#if DEBUG
#Preview {
    OnboardingRemindersStepView(onContinue: {})
        .tint(DesignSystem.Color.green)
}
#endif
