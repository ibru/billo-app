//  Created by Jiri Urbasek on 7/11/26.

import SwiftUI

/// Pain screen: the user's inner monologue as comic-style thought bubbles —
/// each with a colored category icon and a trailing tail of small circles.
/// The thoughts pop up one by one, linger, fade out, and resurface on an
/// endless loop: nagging bill questions popping into someone's head, time
/// after time.
struct OnboardingPainBubblesStepView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onContinue: () -> Void

    @State private var revealedBubbles = 0

    var body: some View {
        OnboardingStepContainer(
            progressIndex: OnboardingStep.painBubbles.progressIndex,
            primaryTitle: "Clear my head",
            onPrimary: onContinue
        ) {
            VStack(spacing: DesignSystem.Spacing.extraLarge) {
                bubblesStack
                    .padding(.top, DesignSystem.Spacing.large)

                VStack(spacing: DesignSystem.Spacing.small) {
                    Text("Bills shouldn’t live in your head", comment: "Onboarding pain (bubbles) title")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text(
                        "No more due dates scattered across emails and apps — and no more wondering if one slipped past you.",
                        comment: "Onboarding pain (bubbles) subtitle"
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
                revealedBubbles = bubbles.count
                return
            }
            // Thoughts resurface on a loop: pop in one by one, linger, fade
            // out together, then start nagging again.
            try? await Task.sleep(for: .milliseconds(300))
            while !Task.isCancelled {
                for index in 1...bubbles.count {
                    withAnimation(.spring(duration: 0.5, bounce: 0.45)) { revealedBubbles = index }
                    try? await Task.sleep(for: .milliseconds(850))
                }
                try? await Task.sleep(for: .milliseconds(2_400))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.5)) { revealedBubbles = 0 }
                try? await Task.sleep(for: .milliseconds(800))
            }
        }
    }

    // MARK: - Bubbles

    private struct ThoughtBubble {
        let text: Text
        let iconName: String
        let iconColor: SwiftUI.Color
        let alignment: Alignment
        let rotation: Double
    }

    private var bubbles: [ThoughtBubble] {
        [
            ThoughtBubble(
                text: Text("Was the electricity due yesterday?", comment: "Onboarding pain thought bubble"),
                iconName: DefaultCategoryIdentifier.utilities.systemImageName,
                iconColor: SwiftUI.Color(hex: DefaultCategoryIdentifier.utilities.colorHex),
                alignment: .leading,
                rotation: -2.5
            ),
            ThoughtBubble(
                text: Text("What’s coming out before payday?", comment: "Onboarding pain thought bubble"),
                iconName: "banknote.fill",
                iconColor: DesignSystem.Color.greenIncome,
                alignment: .trailing,
                rotation: 2
            ),
            ThoughtBubble(
                text: Text("Did that subscription just renew again?", comment: "Onboarding pain thought bubble"),
                iconName: DefaultCategoryIdentifier.subscriptions.systemImageName,
                iconColor: SwiftUI.Color(hex: DefaultCategoryIdentifier.subscriptions.colorHex),
                alignment: .leading,
                rotation: -1.5
            ),
        ]
    }

    private var bubblesStack: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            ForEach(Array(bubbles.enumerated()), id: \.offset) { index, bubble in
                let isRevealed = revealedBubbles > index
                thoughtBubbleView(bubble)
                    .rotationEffect(.degrees(bubble.rotation))
                    .frame(maxWidth: .infinity, alignment: bubble.alignment)
                    .opacity(isRevealed ? 1 : 0)
                    .scaleEffect(
                        isRevealed ? 1 : 0.6,
                        anchor: bubble.alignment == .leading ? .bottomLeading : .bottomTrailing
                    )
            }
        }
        .frame(maxWidth: 360)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            "Worried thoughts about bills popping up: was the electricity due yesterday, what’s coming out before payday, did that subscription renew again",
            comment: "Accessibility label for the onboarding pain thought bubbles"
        ))
    }

    /// A comic-style thought bubble: a very round card with a category icon,
    /// plus the classic tail of two shrinking circles pointing down toward
    /// the thinker.
    private func thoughtBubbleView(_ bubble: ThoughtBubble) -> some View {
        HStack(spacing: DesignSystem.Spacing.mediumSmall) {
            Image(systemName: bubble.iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(bubble.iconColor.gradient, in: Circle())

            bubble.text
                .font(.callout.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.mediumSmall)
        .background(.background, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(.separator, lineWidth: 1)
        }
        .cardShadow()
        .overlay(alignment: bubble.alignment == .leading ? .bottomLeading : .bottomTrailing) {
            bubbleTail(pointingFrom: bubble.alignment)
        }
        // Room for the tail circles below the bubble so nothing clips.
        .padding(.bottom, DesignSystem.Spacing.medium)
    }

    /// Two shrinking circles trailing off the bubble's bottom corner —
    /// the "this is a thought" visual cue.
    private func bubbleTail(pointingFrom alignment: Alignment) -> some View {
        let direction: CGFloat = alignment == .leading ? 1 : -1
        return ZStack {
            tailCircle(diameter: 15)
                .offset(x: direction * 28, y: 10)
            tailCircle(diameter: 9)
                .offset(x: direction * 15, y: 21)
        }
        .accessibilityHidden(true)
    }

    private func tailCircle(diameter: CGFloat) -> some View {
        Circle()
            .fill(.background)
            .overlay {
                Circle().strokeBorder(.separator, lineWidth: 1)
            }
            .frame(width: diameter, height: diameter)
            .subtleShadow()
    }
}

#if DEBUG
#Preview {
    OnboardingPainBubblesStepView(onContinue: {})
        .tint(DesignSystem.Color.green)
}
#endif
