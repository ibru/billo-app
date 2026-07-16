//  Created by Jiri Urbasek on 7/10/26.

import SwiftUI

/// Explains income → "what's left" AND where Income lives in the real app:
/// a miniature home screen stages the summary card (income − bills), then —
/// with the same theater choreography as the view-modes step — the floating
/// bottom pill zooms in, the wallet button blinks, and the mini screen
/// "pushes" to the Income list, teaching the access path.
struct OnboardingIncomeNetStepView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let onContinue: () -> Void

    /// iPad and Mac windows (regular × regular) get a larger miniature — the
    /// iPhone-sized stage reads tiny there. iPhone keeps the original size.
    private var isExpansiveLayout: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }

    private var miniScale: CGFloat { isExpansiveLayout ? 1.35 : 1 }

    /// Fixed-size fonts (not text styles) so every piece of the miniature
    /// scales uniformly on expansive layouts. The stage is decorative —
    /// accessibility is served by its combined label, not per-text Dynamic
    /// Type.
    private func miniFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size * miniScale, weight: weight)
    }

    private enum MiniScreen {
        case bills
        case income
    }

    @State private var revealedRows = 0
    @State private var screen: MiniScreen = .bills
    @State private var walletBlinks = false
    @State private var pillZoomsIn = false

    private let sampleIncome: Decimal = 3500
    private let sampleBills: Decimal = 2150
    private var sampleNet: Decimal { sampleIncome - sampleBills }

    var body: some View {
        OnboardingStepContainer(
            progressIndex: OnboardingStep.incomeNet.progressIndex,
            primaryTitle: "Continue",
            onPrimary: onContinue
        ) {
            VStack(spacing: DesignSystem.Spacing.extraLarge) {
                stage
                    .padding(.top, DesignSystem.Spacing.large)

                VStack(spacing: DesignSystem.Spacing.small) {
                    Text("See what’s left every month", comment: "Onboarding income/net title")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text(
                        "Log your paychecks and Billo shows income minus bills — the wallet button on your home screen opens Income anytime.",
                        comment: "Onboarding income/net subtitle"
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
                revealedRows = 3
                return
            }

            // Act one: the summary card fills in, row by row.
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.smooth(duration: 0.45)) { revealedRows = 1 }
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.smooth(duration: 0.45)) { revealedRows = 2 }
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.spring(duration: 0.5, bounce: 0.35)) { revealedRows = 3 }

            // Act two, on loop: zoom the floating pill in (to the front),
            // blink the wallet button, push to the mini Income screen, zoom
            // back out — "THIS button opens your income."
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.8))
                guard !Task.isCancelled else { return }

                withAnimation(.spring(duration: 0.4, bounce: 0.35)) { pillZoomsIn = true }
                try? await Task.sleep(for: .milliseconds(450))

                for _ in 0..<3 {
                    withAnimation(.easeInOut(duration: 0.16)) { walletBlinks = true }
                    try? await Task.sleep(for: .milliseconds(190))
                    withAnimation(.easeInOut(duration: 0.16)) { walletBlinks = false }
                    try? await Task.sleep(for: .milliseconds(170))
                }
                guard !Task.isCancelled else { return }

                withAnimation(.easeInOut(duration: 0.6)) {
                    screen = screen == .bills ? .income : .bills
                }
                try? await Task.sleep(for: .milliseconds(800))

                withAnimation(.spring(duration: 0.4, bounce: 0.2)) { pillZoomsIn = false }
            }
        }
    }

    // MARK: - Stage (miniature home screen)

    private var stage: some View {
        VStack(spacing: 0) {
            miniTopBar

            ZStack {
                summaryCard
                    .opacity(screen == .bills ? 1 : 0)
                incomeScreenMock
                    .opacity(screen == .income ? 1 : 0)
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.mediumSmall)

            // Above the content so the zoomed-in pill renders in front.
            miniBottomBar
                .zIndex(1)
        }
        .background(DesignSystem.Color.groupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge))
        .cardShadow()
        .frame(maxWidth: 360 * miniScale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            "Miniature of the home screen: the wallet button in the floating bottom bar opens the Income screen, where income minus bills shows what’s left",
            comment: "Accessibility label for the onboarding income/net illustration"
        ))
    }

    /// Mirrors the real navigation bar: "Bills" at home, back chevron +
    /// "Income" after the mock push.
    private var miniTopBar: some View {
        ZStack {
            HStack(spacing: DesignSystem.Spacing.extraSmall) {
                if screen == .income {
                    Image(systemName: "chevron.left")
                        .font(miniFont(11, weight: .semibold))
                        .foregroundStyle(.tint)
                        .transition(.opacity)
                }
                Spacer()
            }

            Text(
                screen == .bills
                    ? String(localized: "Bills", comment: "Navigation title in the onboarding income miniature")
                    : String(localized: "Income", comment: "Navigation title in the onboarding income miniature")
            )
            .font(miniFont(15, weight: .semibold))
            .contentTransition(.opacity)
        }
        .padding(.horizontal, DesignSystem.Spacing.mediumSmall)
        .padding(.vertical, DesignSystem.Spacing.small)
    }

    /// Mirrors the real floating quick-actions pill (payment history +
    /// income), scaled to the miniature.
    private var miniBottomBar: some View {
        HStack {
            Spacer()

            HStack(spacing: 0) {
                Image(systemName: "clock.arrow.circlepath")
                    .frame(width: 42 * miniScale, height: 34 * miniScale)

                Divider()
                    .frame(height: 18 * miniScale)

                Image(systemName: "wallet.bifold")
                    // Emphatic blink: a big size pulse with an opacity dip,
                    // so the eye lands on the income button itself.
                    .scaleEffect(walletBlinks ? 1.5 : 1)
                    .opacity(walletBlinks ? 0.35 : 1)
                    .frame(width: 42 * miniScale, height: 34 * miniScale)
            }
            .font(miniFont(15, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(DesignSystem.Color.greenIncome)
            .background(.background, in: Capsule())
            .cardShadow()
            // Zooms toward the content (anchored at its bottom-trailing
            // corner) and in front of it while the mini screen switches.
            .scaleEffect(pillZoomsIn ? 1.5 : 1, anchor: .bottomTrailing)
        }
        .padding(.horizontal, DesignSystem.Spacing.mediumSmall)
        .padding(.bottom, DesignSystem.Spacing.small)
    }

    // MARK: - Mini screens

    private var summaryCard: some View {
        VStack(spacing: DesignSystem.Spacing.mediumSmall) {
            amountRow(
                label: Text("Income", comment: "Onboarding mock summary row"),
                amount: sampleIncome,
                prefix: "+",
                color: DesignSystem.Color.greenIncome,
                barFraction: 1.0,
                revealAt: 1
            )
            amountRow(
                label: Text("Bills", comment: "Onboarding mock summary row"),
                amount: sampleBills,
                prefix: "−",
                color: .secondary,
                barFraction: 0.62,
                revealAt: 2
            )

            Divider()

            HStack {
                Text("Left over", comment: "Onboarding mock summary net row")
                    .font(miniFont(15, weight: .semibold))
                Spacer()
                Text(sampleNet, format: currencyFormat)
                    .font(miniFont(20, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.greenIncome)
            }
            .opacity(revealedRows >= 3 ? 1 : 0)
            .scaleEffect(revealedRows >= 3 ? 1 : 0.85)
        }
        .padding(DesignSystem.Spacing.medium)
        .background(.background, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .cardShadow()
    }

    /// A minimal stand-in for the Income list — one entry plus the add hint,
    /// enough to say "this is where your paychecks live".
    private var incomeScreenMock: some View {
        VStack(spacing: DesignSystem.Spacing.mediumSmall) {
            HStack(spacing: DesignSystem.Spacing.mediumSmall) {
                Image(systemName: "wallet.bifold")
                    .font(miniFont(14, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.greenIncome)
                    .frame(width: 30 * miniScale, height: 30 * miniScale)
                    .background(DesignSystem.Color.greenIncome.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text("Salary", comment: "Onboarding mock income row")
                        .font(miniFont(15, weight: .semibold))
                    Text("Every month · on the 1st", comment: "Onboarding mock income row schedule")
                        .font(miniFont(12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                (Text("+") + Text(sampleIncome, format: currencyFormat))
                    .font(miniFont(15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.greenIncome)
            }
            .padding(DesignSystem.Spacing.medium)
            .background(.background, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
            .cardShadow()

            HStack(spacing: DesignSystem.Spacing.small) {
                Image(systemName: "plus")
                    .font(miniFont(12, weight: .semibold))
                Text("Add income", comment: "Onboarding mock income add-row hint")
                    .font(miniFont(15))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.mediumSmall)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .strokeBorder(.separator, style: StrokeStyle(lineWidth: 1, dash: [5]))
            }
        }
    }

    private func amountRow(
        label: Text,
        amount: Decimal,
        prefix: String,
        color: SwiftUI.Color,
        barFraction: CGFloat,
        revealAt threshold: Int
    ) -> some View {
        let isRevealed = revealedRows >= threshold
        return VStack(spacing: DesignSystem.Spacing.extraSmall) {
            HStack {
                label.font(miniFont(15))
                Spacer()
                (Text(prefix) + Text(amount, format: currencyFormat))
                    .font(miniFont(15, weight: .semibold))
                    .foregroundStyle(color)
            }
            Capsule()
                .fill(color == .secondary ? AnyShapeStyle(.quaternary) : AnyShapeStyle(color.gradient))
                .frame(height: 6 * miniScale)
                .frame(maxWidth: .infinity, alignment: .leading)
                .scaleEffect(x: isRevealed ? barFraction : 0.001, anchor: .leading)
        }
        .opacity(isRevealed ? 1 : 0)
    }

    private var currencyFormat: Decimal.FormatStyle.Currency {
        // Illustrative figures only — the user picks their real currency later.
        .currency(code: "USD").precision(.fractionLength(0))
    }
}

#if DEBUG
#Preview {
    OnboardingIncomeNetStepView(onContinue: {})
        .tint(DesignSystem.Color.green)
}
#endif
