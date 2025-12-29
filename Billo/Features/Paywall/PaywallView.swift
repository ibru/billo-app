//  Created by Jiri Urbasek on 12/28/25.

import StoreKit
import SwiftUI

enum PaywallContext: Hashable, Sendable {
    case firstLaunch
}

enum PaywallResult: Hashable, Sendable {
    case purchased
    case dismissed
}

struct PaywallView: View {
    @Environment(StoreKitManager.self) private var storeKit
    @Environment(\.dismiss) private var dismiss

    let context: PaywallContext
    let isDismissible: Bool
    let dismissOnFinish: Bool
    let onFinished: (PaywallResult) -> Void

    @State private var selectedPlan: SelectedPlan = .weekly
    @State private var isFreeTrialToggleOn: Bool = true
    @State private var isPurchasing: Bool = false
    @State private var errorMessage: String?

    private var selectedProductID: String {
        selectedPlan.productID
    }

    private var weeklyProduct: Product? {
        storeKit.products.first { $0.id == StoreKitManager.ProductID.weekly }
    }

    private var yearlyProduct: Product? {
        storeKit.products.first { $0.id == StoreKitManager.ProductID.yearly }
    }

    private enum FallbackPricing {
        static let weeklyPrice: Decimal = 3.99
        static let yearlyPrice: Decimal = 39.99
    }

    private var weeklyDisplayPrice: String {
        weeklyProduct?.displayPrice ?? currencyString(amount: FallbackPricing.weeklyPrice, locale: .current)
    }

    private var yearlyDisplayPrice: String {
        yearlyProduct?.displayPrice ?? currencyString(amount: FallbackPricing.yearlyPrice, locale: .current)
    }

    private var weeklySubtitleText: String {
        let trialText = introductoryOfferText(weeklyProduct)
        if trialText.isEmpty {
            return "Then \(weeklyDisplayPrice)/week • cancel anytime"
        }
        return "\(trialText) • then \(weeklyDisplayPrice)/week • cancel anytime"
    }

    private var yearlySubtitleText: String {
        "Best value • \(yearlyMonthlyText)"
    }

    private var yearlyMonthlyText: String {
        if let yearlyProduct {
            return yearlySavingsText(yearly: yearlyProduct)
        }

        let monthly = FallbackPricing.yearlyPrice / 12
        let monthlyString = currencyString(amount: monthly, locale: .current)
        return "\(monthlyString)/mo"
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.large) {
                        heroSection
                        benefitsList
                        subscriptionOptions
                        purchaseButton
                        securityNote
                        legalLinks
                    }
                    .padding(.horizontal, DesignSystem.Spacing.large)
                    .padding(.top, DesignSystem.Spacing.small)
                    .padding(.bottom, DesignSystem.Spacing.extraLarge)
                }
            }
        }
        .task {
            Logger.log("Paywall shown (context: \(String(describing: context)))", level: .info)
            await storeKit.loadProductsIfNeeded()
            syncToggleWithSelection()
        }
        .alert("Something went wrong", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            if isDismissible {
                Button {
                    finish(.dismissed)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("paywall_close")
            }

            Spacer()

            Button("Restore") {
                Logger.log("Paywall restore tapped", level: .info)
                Task {
                    do {
                        try await storeKit.restorePurchases()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("paywall_restore")
        }
        .padding(.horizontal, DesignSystem.Spacing.large)
        .padding(.vertical, 12)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(spacing: DesignSystem.Spacing.extraSmall) {
                Text(headline)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(subheadline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, DesignSystem.Spacing.small)
    }

    private var benefitsList: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            BenefitRow(icon: "sparkles", text: "Peace of mind about what’s due next")
            BenefitRow(icon: "tray.full", text: "Everything in one place — no scattered notes")
            BenefitRow(icon: "bell.badge", text: "Stay ahead of late fees and surprises")
            BenefitRow(icon: "checkmark.circle", text: "Build a simple weekly routine that sticks")
        }
        .padding(DesignSystem.Spacing.large)
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Subscription Options

    private var subscriptionOptions: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            switch storeKit.productsState {
            case .idle, .loading:
                ProgressView()
                    .padding(.vertical, DesignSystem.Spacing.large)

            case .failed(let message):
                VStack(spacing: DesignSystem.Spacing.medium) {
                    Text(message)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Retry") {
                        Logger.log("Paywall retry tapped", level: .info)
                        Task {
                            await storeKit.refreshEntitlements()
                            await storeKit.loadProducts()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .accessibilityIdentifier("paywall_retry")
                }
                .padding(.vertical, DesignSystem.Spacing.large)

            case .loaded:
                freeTrialToggle

                SubscriptionOptionRow(
                    title: "Weekly — \(weeklyDisplayPrice)",
                    subtitle: weeklySubtitleText,
                    isSelected: selectedPlan == .weekly,
                    action: {
                        selectedPlan = .weekly
                        syncToggleWithSelection()
                        Logger.log("Paywall plan selected: weekly", level: .debug)
                    }
                )

                SubscriptionOptionRow(
                    title: "Yearly — \(yearlyDisplayPrice)",
                    subtitle: yearlySubtitleText,
                    isSelected: selectedPlan == .yearly,
                    savingsBadge: savingsPercentage,
                    action: {
                        selectedPlan = .yearly
                        syncToggleWithSelection()
                        Logger.log("Paywall plan selected: yearly", level: .debug)
                    }
                )
            }
        }
    }

    private var freeTrialToggle: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Text("Not sure yet? Enable Free Trial")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Toggle("", isOn: Binding(
                get: { isFreeTrialToggleOn },
                set: { newValue in
                    isFreeTrialToggleOn = newValue
                    selectedPlan = newValue ? .weekly : .yearly
                    Logger.log("Paywall free trial toggle: \(newValue ? "on" : "off")", level: .debug)
                }
            ))
            .labelsHidden()
            .tint(.accentColor)
            .accessibilityLabel("Free trial")
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, 12)
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Purchase

    private var purchaseButton: some View {
        Button {
            Task { await purchaseSelected() }
        } label: {
            Group {
                if isPurchasing {
                    ProgressView()
                } else if storeKit.isPro {
                    Text("You’re all set")
                } else {
                    Text(selectedPlan.purchaseButtonTitle)
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .disabled(isPurchasing || storeKit.isPro || storeKit.productsState != .loaded)
        .accessibilityIdentifier("paywall_continue")
    }

    private var securityNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
            Text("App Store secure • cancel anytime")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var legalLinks: some View {
        HStack(spacing: 8) {
            if let termsURL = URL(string: "https://example.com/terms") {
                Link("Terms of Use", destination: termsURL)
            }

            Text("•")
                .foregroundStyle(.tertiary)

            if let privacyURL = URL(string: "https://example.com/privacy") {
                Link("Privacy Policy", destination: privacyURL)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Helpers

    private var headline: String {
        switch context {
        case .firstLaunch:
            return "Stay on top of every bill"
        }
    }

    private var subheadline: String {
        switch context {
        case .firstLaunch:
            return "Try Pro free. Cancel anytime."
        }
    }

    private func purchaseSelected() async {
        guard let product = storeKit.products.first(where: { $0.id == selectedProductID }) else { return }

        Logger.log("Paywall purchase started (productID: \(product.id))", level: .info)
        isPurchasing = true
        defer { isPurchasing = false }

        let result = await storeKit.purchase(product)
        switch result {
        case .success:
            Logger.log("Paywall purchase success (productID: \(product.id))", level: .info)
            finish(.purchased)

        case .failure(let error):
            Logger.log("Paywall purchase failed (productID: \(product.id), error: \(error))", level: .warning)
            if error != .cancelled {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func finish(_ result: PaywallResult) {
        switch result {
        case .purchased:
            break
        case .dismissed:
            Logger.log("Paywall dismissed", level: .info)
        }

        onFinished(result)
        if dismissOnFinish {
            dismiss()
        }
    }

    private func syncToggleWithSelection() {
        isFreeTrialToggleOn = (selectedPlan == .weekly)
    }

    private func yearlySavingsText(yearly: Product) -> String {
        let monthlyEquivalent = yearly.price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = yearly.priceFormatStyle.locale
        let monthlyString = formatter.string(from: monthlyEquivalent as NSDecimalNumber) ?? ""
        return "\(monthlyString)/mo"
    }

    private func currencyString(amount: Decimal, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        return formatter.string(from: amount as NSDecimalNumber) ?? ""
    }

    private var savingsPercentage: String? {
        let weeklyPrice = weeklyProduct?.price ?? FallbackPricing.weeklyPrice
        let yearlyPrice = yearlyProduct?.price ?? FallbackPricing.yearlyPrice

        guard let percent = PaywallPricing.savingsPercentage(weeklyPrice: weeklyPrice, yearlyPrice: yearlyPrice) else { return nil }
        return "SAVE \(percent)%"
    }

    private func introductoryOfferText(_ product: Product?) -> String {
        guard
            let product,
            let subscription = product.subscription,
            let offer = subscription.introductoryOffer
        else { return "" }

        let period = offer.period
        let unit: PaywallPricing.SubscriptionUnit? = switch period.unit {
        case .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        @unknown default: nil
        }

        guard let unit else { return "" }
        return PaywallPricing.introductoryOfferText(value: period.value, unit: unit)
    }
}

private enum SelectedPlan: Hashable {
    case weekly
    case yearly

    var productID: String {
        switch self {
        case .weekly:
            return StoreKitManager.ProductID.weekly
        case .yearly:
            return StoreKitManager.ProductID.yearly
        }
    }

    var purchaseButtonTitle: String {
        switch self {
        case .weekly:
            return "Try Pro free"
        case .yearly:
            return "Save yearly"
        }
    }
}

private struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 22)
                .accessibilityHidden(true)

            Text(text)
                .font(.subheadline)

            Spacer()
        }
    }
}

private struct SubscriptionOptionRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    var savingsBadge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if let badge = savingsBadge {
                            Text(badge)
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color(.separator), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 16, height: 16)
                    }
                }
            }
            .padding(DesignSystem.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.accentColor : Color(.separator), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG && targetEnvironment(simulator)
#Preview {
    let storeKit = StoreKitManager()
    return PaywallView(context: .firstLaunch, isDismissible: true, dismissOnFinish: true, onFinished: { _ in })
        .environment(storeKit)
}
#endif
