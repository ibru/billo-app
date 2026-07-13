//  Created by Jiri Urbasek on 7/10/26.

import SwiftUI

/// Shared chrome for every onboarding step: segmented progress bar on top,
/// scrollable content, and a pinned full-width primary CTA (with optional
/// plain-style secondary action beneath it).
struct OnboardingStepContainer<Content: View>: View {
    enum PrimaryButtonState {
        case enabled
        case disabled
        case hidden
        case loading
    }

    let progressIndex: Int?
    let primaryTitle: LocalizedStringKey
    var primaryState: PrimaryButtonState = .enabled
    let onPrimary: () -> Void
    var secondaryTitle: LocalizedStringKey?
    var onSecondary: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            if let progressIndex {
                OnboardingProgressBar(currentIndex: progressIndex, total: OnboardingStep.progressTotal)
                    .padding(.horizontal, DesignSystem.Spacing.large)
                    .frame(maxWidth: 560)
                    .padding(.top, DesignSystem.Spacing.medium)
            }

            // GeometryReader + minHeight centers short content vertically —
            // without it, steps sit pinned to the top with a large void on
            // iPad-sized screens. Taller content scrolls naturally.
            GeometryReader { proxy in
                ScrollView {
                    content
                        .padding(.horizontal, DesignSystem.Spacing.large)
                        .padding(.vertical, DesignSystem.Spacing.large)
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .safeAreaInset(edge: .bottom) {
            footer
        }
        .background(DesignSystem.Color.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var footer: some View {
        if primaryState != .hidden || secondaryTitle != nil {
            VStack(spacing: DesignSystem.Spacing.small) {
                if primaryState != .hidden {
                    Button(action: onPrimary) {
                        ZStack {
                            Text(primaryTitle)
                                .font(.headline)
                                .opacity(primaryState == .loading ? 0 : 1)
                            if primaryState == .loading {
                                ProgressView()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(primaryState == .disabled || primaryState == .loading)
                    .accessibilityIdentifier("onboarding_continue")
                }

                if let secondaryTitle, let onSecondary {
                    Button(action: onSecondary) {
                        Text(secondaryTitle)
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    // While the primary action is in flight, a live secondary
                    // would open a second completion path (e.g. "Not now"
                    // racing an awaited permission request).
                    .disabled(primaryState == .loading)
                    .accessibilityIdentifier("onboarding_secondary")
                }
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, DesignSystem.Spacing.large)
            .padding(.top, DesignSystem.Spacing.small)
            .padding(.bottom, DesignSystem.Spacing.large)
            .frame(maxWidth: .infinity)
            .background(DesignSystem.Color.background.opacity(0.94))
        }
    }
}

/// Segmented capsule progress bar — one segment per progress step, filled up
/// to (and including) the current index. Steps that can't use
/// `OnboardingStepContainer` (e.g. the currency step, which embeds a
/// full-height view with its own buttons) place it directly.
struct OnboardingProgressBar: View {
    let currentIndex: Int
    let total: Int

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.extraSmall) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= currentIndex ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                    .frame(height: 4)
            }
        }
        .animation(.smooth(duration: 0.35), value: currentIndex)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            "Step \(currentIndex + 1) of \(total)",
            comment: "Accessibility label for the onboarding progress bar"
        ))
    }
}

#if DEBUG
#Preview("Enabled + secondary") {
    OnboardingStepContainer(
        progressIndex: 2,
        primaryTitle: "Continue",
        primaryState: .enabled,
        onPrimary: {},
        secondaryTitle: "Skip for now",
        onSecondary: {}
    ) {
        VStack(spacing: DesignSystem.Spacing.large) {
            Text("Sample step").font(.title.bold())
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(.quaternary)
                .frame(height: 300)
        }
    }
}

#Preview("Disabled") {
    OnboardingStepContainer(
        progressIndex: 5,
        primaryTitle: "Continue",
        primaryState: .disabled,
        onPrimary: {}
    ) {
        Text("Pick something first").font(.title2)
    }
}

#Preview("Loading") {
    OnboardingStepContainer(
        progressIndex: 7,
        primaryTitle: "Turn On Reminders",
        primaryState: .loading,
        onPrimary: {}
    ) {
        Text("Waiting for permission…").font(.title2)
    }
}

#Preview("Hidden primary") {
    OnboardingStepContainer(
        progressIndex: 4,
        primaryTitle: "Continue",
        primaryState: .hidden,
        onPrimary: {}
    ) {
        Text("Step with its own button").font(.title2)
    }
}
#endif
