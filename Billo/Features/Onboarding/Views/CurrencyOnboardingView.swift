//  Created by Jiri Urbasek on 12/09/25.

import SwiftUI

struct CurrencyOnboardingView: View {
    @Environment(AppSettingsModel.self) private var appSettingsModel
    @Environment(AnalyticsModel.self) private var analytics

    @State private var selectedCurrencyCode: String?
    @State private var showingCurrencyPicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var hasDeviceCurrency: Bool {
        Locale.current.currency?.identifier != nil
    }

    private var selectedCurrency: CurrencyItem? {
        guard let code = selectedCurrencyCode else { return nil }
        return CurrencyItem(code: code, name: CurrencyItem.localizedName(for: code))
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
        VStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: "banknote")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: DesignSystem.Spacing.small) {
                Text("What's your preferred currency?")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("This will be used to display amounts for your bills and payments.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
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
        VStack(spacing: DesignSystem.Spacing.medium) {
            HStack(spacing: DesignSystem.Spacing.medium) {
                Text(currency.symbol)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.name)
                        .font(.headline)
                    Text(currency.code)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(DesignSystem.Spacing.large)
            .background(.fill.tertiary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
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
            .background(.fill.tertiary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var buttonsSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            // Secondary button to choose different currency (only shown when currency is selected)
            if selectedCurrency != nil {
                Button {
                    showingCurrencyPicker = true
                } label: {
                    Text("Choose a different currency")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }

            // Primary button
            Button {
                guard let code = selectedCurrencyCode else { return }
                Task {
                    isLoading = true
                    defer { isLoading = false }
                    do {
                        try await appSettingsModel.setCurrency(code)
                        analytics.capture(.currencyChanged(currencyCode: code, source: "onboarding"))
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
}

#Preview("No Device Currency") {
    let preview = BilloPreviewContainer.empty()
    return CurrencyOnboardingView()
        .environment(preview.appSettingsModel)
        .environment(AnalyticsModel())
}
