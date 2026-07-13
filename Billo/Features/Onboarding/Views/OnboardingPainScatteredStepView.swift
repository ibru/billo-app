//  Created by Jiri Urbasek on 7/11/26.

import SwiftUI

/// Pain screen, variant B: a scattered collage of the places bills hide —
/// email, paper letters, banking apps, calendar — drifting gently apart to
/// visualize the fragmentation ("no single place has the full picture").
struct OnboardingPainScatteredStepView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onContinue: () -> Void

    @State private var revealedIcons = 0
    @State private var isFloating = false

    var body: some View {
        OnboardingStepContainer(
            progressIndex: OnboardingStep.painScattered.progressIndex,
            primaryTitle: "Sounds familiar",
            onPrimary: onContinue
        ) {
            VStack(spacing: DesignSystem.Spacing.extraLarge) {
                scatteredCollage
                    .padding(.top, DesignSystem.Spacing.large)

                VStack(spacing: DesignSystem.Spacing.small) {
                    Text("Your bills live everywhere", comment: "Onboarding pain (scattered) title")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text(
                        "Email, paper letters, banking apps, calendar reminders — no single place has the full picture.",
                        comment: "Onboarding pain (scattered) subtitle"
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
                revealedIcons = sources.count
                return
            }
            try? await Task.sleep(for: .milliseconds(250))
            for index in 1...sources.count {
                withAnimation(.spring(duration: 0.45, bounce: 0.45)) { revealedIcons = index }
                try? await Task.sleep(for: .milliseconds(180))
            }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isFloating = true
            }
        }
    }

    private struct BillSource {
        let symbol: String
        let tint: Color
        let offset: CGSize
        let rotation: Double
        let floatPhase: CGFloat
    }

    private var sources: [BillSource] {
        [
            BillSource(symbol: "envelope.fill", tint: .blue, offset: CGSize(width: -110, height: -70), rotation: -10, floatPhase: 6),
            BillSource(symbol: "doc.text.fill", tint: .orange, offset: CGSize(width: 95, height: -85), rotation: 8, floatPhase: -5),
            BillSource(symbol: "building.columns.fill", tint: .indigo, offset: CGSize(width: 0, height: -10), rotation: -4, floatPhase: 7),
            BillSource(symbol: "calendar", tint: .red, offset: CGSize(width: -95, height: 65), rotation: 6, floatPhase: -6),
            BillSource(symbol: "creditcard.fill", tint: .teal, offset: CGSize(width: 105, height: 55), rotation: -8, floatPhase: 5),
        ]
    }

    private var scatteredCollage: some View {
        ZStack {
            ForEach(Array(sources.enumerated()), id: \.offset) { index, source in
                let isRevealed = revealedIcons > index
                Image(systemName: source.symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(source.tint)
                    .frame(width: 64, height: 64)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
                    .cardShadow()
                    .rotationEffect(.degrees(source.rotation))
                    .offset(source.offset)
                    .offset(y: isFloating ? source.floatPhase : 0)
                    .opacity(isRevealed ? 1 : 0)
                    .scaleEffect(isRevealed ? 1 : 0.5)
            }
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            "Bills scattered across email, paper letters, banking apps, calendars, and cards",
            comment: "Accessibility label for the onboarding scattered-sources illustration"
        ))
    }
}

#if DEBUG
#Preview {
    OnboardingPainScatteredStepView(onContinue: {})
        .tint(DesignSystem.Color.green)
}
#endif
