//  Created by Jiri Urbasek on 12/09/25.

import SwiftUI

struct CurrencyOnboardingView: View {
    @Environment(AppSettingsModel.self) private var appSettingsModel
    @Environment(AnalyticsModel.self) private var analytics

    /// Invoked after the user's own confirm action successfully saves the
    /// currency. The first-launch flow advances on THIS (not on observing
    /// `currencyCode` change), so a CloudKit-synced currency arriving while
    /// the screen is up is never mistaken for a local pick. Nil when used
    /// standalone (e.g. `AppRootView` fallback).
    var onSaved: (() -> Void)? = nil

    @State private var selectedCurrencyCode: String?
    @State private var showingCurrencyPicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var selectedCurrency: CurrencyItem? {
        guard let code = selectedCurrencyCode else { return nil }
        return CurrencyItem(code: code, name: CurrencyItem.localizedName(for: code))
    }

    private var isDeviceCurrency: Bool {
        selectedCurrencyCode != nil && selectedCurrencyCode == Locale.current.currency?.identifier
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            headerSection

            Spacer()

            currencyDisplaySection

            Spacer()

            buttonsSection
        }
        .padding(.horizontal, DesignSystem.Spacing.large)
        .padding(.bottom, DesignSystem.Spacing.large)
        .frame(maxWidth: 560)
        .analyticsScreen(.onboardingCurrency)
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $showingCurrencyPicker) {
            CurrencyPickerSheet(
                selectedCurrency: Binding(
                    get: { selectedCurrencyCode ?? "USD" },
                    set: { selectedCurrencyCode = $0 }
                )
            )
        }
        .onAppear {
            if selectedCurrencyCode == nil {
                selectedCurrencyCode = Locale.current.currency?.identifier
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.extraLarge) {
            currencySymbolHero

            VStack(spacing: DesignSystem.Spacing.small) {
                Text("What’s your currency?", comment: "Onboarding currency title")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(
                    "Every amount in Billo — bills, income, what’s left — will use it.",
                    comment: "Onboarding currency subtitle"
                )
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
        }
    }

    /// The selected currency's symbol in a tinted circle, with a few faded
    /// companion symbols floating around it — updates with a spring when the
    /// user picks a different currency.
    private var currencySymbolHero: some View {
        ZStack {
            ambientBubble(ambientSymbols[0], offset: CGSize(width: -116, height: -30), size: 44)
            ambientBubble(ambientSymbols[1], offset: CGSize(width: 112, height: -48), size: 40)
            ambientBubble(ambientSymbols[2], offset: CGSize(width: 96, height: 44), size: 34)

            Circle()
                .fill(.tint.opacity(0.14))
                .frame(width: 120, height: 120)

            Text(selectedCurrency?.symbol ?? "¤")
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(.tint)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .frame(maxWidth: 96)
                .contentTransition(.numericText())
        }
        .frame(height: 150)
        .animation(.spring(duration: 0.5, bounce: 0.3), value: selectedCurrencyCode)
        .accessibilityHidden(true)
    }

    /// Decorative symbols distinct from the selection, so the hero never
    /// shows the picked currency twice.
    private var ambientSymbols: [String] {
        let candidates = ["€", "£", "¥", "$", "₹"]
        return Array(candidates.filter { $0 != selectedCurrency?.symbol }.prefix(3))
    }

    private func ambientBubble(_ symbol: String, offset: CGSize, size: CGFloat) -> some View {
        Text(symbol)
            .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .background(.fill.tertiary, in: Circle())
            .offset(offset)
    }

    @ViewBuilder
    private var currencyDisplaySection: some View {
        if let currency = selectedCurrency {
            selectedCurrencyCard(currency: currency)
        } else {
            pickCurrencyButton
        }
    }

    private func selectedCurrencyCard(currency: CurrencyItem) -> some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            Button {
                showingCurrencyPicker = true
            } label: {
                HStack(spacing: DesignSystem.Spacing.medium) {
                    Text(currency.symbol)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tint)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .frame(width: 48, height: 48)
                        .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(currency.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(currency.code)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(DesignSystem.Spacing.medium)
                .background(.background, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                        .strokeBorder(.separator, lineWidth: 1)
                }
                .cardShadow()
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text(
                "Opens the currency picker",
                comment: "Accessibility hint for the selected-currency card"
            ))

            Group {
                if isDeviceCurrency {
                    Text(
                        "Detected from your device — tap to change.",
                        comment: "Onboarding currency hint under the selected-currency card"
                    )
                } else {
                    Text(
                        "Tap to change.",
                        comment: "Onboarding currency hint under the selected-currency card"
                    )
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var pickCurrencyButton: some View {
        Button {
            showingCurrencyPicker = true
        } label: {
            HStack {
                Image(systemName: "magnifyingglass")
                Text("Pick your currency")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.large)
            .background(.background, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .strokeBorder(.separator, lineWidth: 1)
            }
            .cardShadow()
        }
        .buttonStyle(.plain)
    }

    private var buttonsSection: some View {
        // Primary button
        Button {
            // Reentrancy: `.disabled(isLoading)` only kicks in after a
            // re-render — set the flag synchronously so a rapid second
            // tap can't spawn a second save/analytics/onSaved sequence.
            guard let code = selectedCurrencyCode, !isLoading else { return }
            isLoading = true
            Task {
                defer { isLoading = false }
                do {
                    try await appSettingsModel.setCurrency(code)
                    analytics.capture(.currencyChanged(currencyCode: code, source: "onboarding"))
                    onSaved?()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } label: {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text(primaryButtonTitle)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(selectedCurrencyCode == nil || isLoading)
    }

    private var primaryButtonTitle: LocalizedStringKey {
        if let currency = selectedCurrency {
            "Use \(currency.code)"
        } else {
            "Continue"
        }
    }
}

#Preview("With Device Currency") {
    let preview = BilloPreviewContainer.empty()
    return CurrencyOnboardingView()
        .environment(preview.appSettingsModel)
        .environment(AnalyticsModel())
        .tint(DesignSystem.Color.green)
}

#Preview("No Device Currency") {
    let preview = BilloPreviewContainer.empty()
    return CurrencyOnboardingView()
        .environment(preview.appSettingsModel)
        .environment(AnalyticsModel())
        .tint(DesignSystem.Color.green)
}
