//  Created by Jiri Urbasek on 12/28/25.

import StoreKit
import SwiftUI

enum PaywallContext: Hashable, Sendable, Identifiable, CaseIterable {
    case firstLaunch
    case billLimit
    case incomeLimit
    case partialPayment
    case customRecurrence
    case charts
    case dataExport
    /// Display cap: over-limit items exist (created while Pro) but are hidden.
    /// Distinct from `.billLimit`/`.incomeLimit` (tried to add a new item) —
    /// "wants to see existing data" is a different purchase motivation.
    case hiddenBills
    case hiddenIncomes
    /// Deliberate upgrade from the Settings status row — the only entry
    /// point that isn't a feature gate.
    case settings

    /// Stable snake_case key — the analytics context, the `proGateHit`
    /// feature, and the sheet identity. The funnel joins `pro gate hit` to
    /// `paywall shown` on this key, so it must never drift per call site.
    var analyticsKey: String {
        switch self {
        case .firstLaunch: "first_launch"
        case .billLimit: "bill_limit"
        case .incomeLimit: "income_limit"
        case .partialPayment: "partial_payment"
        case .customRecurrence: "custom_recurrence"
        case .charts: "charts"
        case .dataExport: "data_export"
        case .hiddenBills: "hidden_bills"
        case .hiddenIncomes: "hidden_incomes"
        case .settings: "settings"
        }
    }

    var id: String { analyticsKey }
}

enum PaywallResult: Hashable, Sendable {
    case purchased
    case dismissed
}

struct PaywallView: View {
    @Environment(StoreKitManager.self) private var storeKit
    @Environment(AnalyticsModel.self) private var analytics
    @Environment(\.dismiss) private var dismiss

    let context: PaywallContext
    let isDismissible: Bool
    let dismissOnFinish: Bool
    let onFinished: (PaywallResult) -> Void

    @State private var selectedPlan: SelectedPlan = .yearly
    @State private var isPurchasing: Bool = false
    @State private var errorMessage: String?
    /// Set by `finish(_:)`. When presented as a sheet, an interactive
    /// swipe-down bypasses the close button — `onDisappear` uses this flag to
    /// still capture `paywallClosed` exactly once.
    @State private var didFinish: Bool = false

    private var selectedProductID: String {
        selectedPlan.productID
    }

    private var monthlyProduct: Product? {
        storeKit.products.first { $0.id == StoreKitManager.ProductID.monthly }
    }

    private var yearlyProduct: Product? {
        storeKit.products.first { $0.id == StoreKitManager.ProductID.yearly }
    }

    private var lifetimeProduct: Product? {
        storeKit.products.first { $0.id == StoreKitManager.ProductID.lifetime }
    }

    private enum FallbackPricing {
        static let monthlyPrice: Decimal = 4.99
        static let yearlyPrice: Decimal = 29.99
        static let lifetimePrice: Decimal = 69.99
    }

    private var monthlyDisplayPrice: String {
        monthlyProduct?.displayPrice ?? currencyString(amount: FallbackPricing.monthlyPrice, locale: .current)
    }

    private var yearlyDisplayPrice: String {
        yearlyProduct?.displayPrice ?? currencyString(amount: FallbackPricing.yearlyPrice, locale: .current)
    }

    private var lifetimeDisplayPrice: String {
        lifetimeProduct?.displayPrice ?? currencyString(amount: FallbackPricing.lifetimePrice, locale: .current)
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
            DesignSystem.Color.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.large) {
                        heroSection
                        benefitsList
                        subscriptionOptions
                        purchaseSection
                        legalLinks
                    }
                    .padding(.horizontal, DesignSystem.Spacing.large)
                    .padding(.top, DesignSystem.Spacing.small)
                    .padding(.bottom, DesignSystem.Spacing.extraLarge)
                }
            }
        }
        .analyticsScreen(.paywall, properties: ["context": analyticsContext])
        .task {
            Logger.log("Paywall shown (context: \(String(describing: context)))", level: .info)
            analytics.capture(.paywallShown(context: analyticsContext))
            await storeKit.loadProductsIfNeeded()
        }
        .alert("Something went wrong", isPresented: Binding(isPresent: $errorMessage)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onDisappear {
            if !didFinish {
                Logger.log("Paywall dismissed interactively", level: .info)
                analytics.capture(.paywallClosed(context: analyticsContext))
            }
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
        }
        .padding(.horizontal, DesignSystem.Spacing.large)
        .padding(.vertical, 12)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            AppIconView(size: 96)
                .cardShadow()

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
        VStack(spacing: DesignSystem.Spacing.mediumSmall) {
            BenefitRow(icon: "chart.pie", text: "Unlimited bills and charts — know where your money goes")
            BenefitRow(icon: "creditcard", text: "Partial payments — pay bills your way")
            BenefitRow(icon: "calendar.badge.clock", text: "Custom repeat schedules for any bill")
        }
        .padding(DesignSystem.Spacing.medium)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
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
                SubscriptionOptionRow(
                    title: "Monthly — \(monthlyDisplayPrice)",
                    subtitle: "Billed monthly • cancel anytime",
                    isSelected: selectedPlan == .monthly,
                    action: { select(.monthly) }
                )

                SubscriptionOptionRow(
                    title: "Yearly — \(yearlyDisplayPrice)",
                    subtitle: yearlySubtitleText,
                    isSelected: selectedPlan == .yearly,
                    savingsBadge: savingsPercentage,
                    action: { select(.yearly) }
                )

                SubscriptionOptionRow(
                    title: "Lifetime — \(lifetimeDisplayPrice)",
                    subtitle: "Pay once • yours forever",
                    isSelected: selectedPlan == .lifetime,
                    action: { select(.lifetime) }
                )
            }
        }
    }

    private func select(_ plan: SelectedPlan) {
        selectedPlan = plan
        Logger.log("Paywall plan selected: \(plan.analyticsPlanId)", level: .debug)
        analytics.capture(.paywallPlanSelected(planId: plan.analyticsPlanId, context: analyticsContext))
    }

    // MARK: - Purchase

    private var purchaseSection: some View {
        purchaseButton
    }

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

    private var legalLinks: some View {
        HStack(spacing: 16) {
            if let termsURL = URL(string: "https://example.com/terms") {
                Link("Terms of Use", destination: termsURL)
            }

            Text("•")
                .foregroundStyle(.tertiary)

            Button("Restore") {
                Logger.log("Paywall restore tapped", level: .info)
                analytics.capture(.paywallRestoreAttempted(context: analyticsContext))
                Task {
                    do {
                        try await storeKit.restorePurchases()
                        // A clean sync with no active entitlement is not a success.
                        if storeKit.isPro {
                            analytics.capture(.paywallRestoreSucceeded(context: analyticsContext))
                        } else {
                            analytics.capture(.paywallRestoreFailed(
                                context: analyticsContext,
                                error: "no_purchases_found"
                            ))
                        }
                    } catch {
                        // Stable key only — localizedDescription is locale-dependent
                        // (unaggregatable) and an uncontrolled string channel.
                        // The detailed error stays in the on-device log/alert.
                        analytics.capture(.paywallRestoreFailed(
                            context: analyticsContext,
                            error: "sync_failed"
                        ))
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .accessibilityIdentifier("paywall_restore")

            Text("•")
                .foregroundStyle(.tertiary)

            if let privacyURL = URL(string: "https://example.com/privacy") {
                Link("Privacy Policy", destination: privacyURL)
            }
        }
        .padding(.vertical, 8)
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Helpers

    private var headline: String {
        switch context {
        case .firstLaunch:
            return String(localized: "Stay on top of every bill", comment: "Paywall headline: first launch")
        case .billLimit:
            return String(localized: "You've outgrown the free plan", comment: "Paywall headline: free bill limit reached")
        case .incomeLimit:
            return String(localized: "All your income, one picture", comment: "Paywall headline: free income limit reached")
        case .partialPayment:
            return String(localized: "Pay bills your way", comment: "Paywall headline: partial payment gate")
        case .customRecurrence:
            return String(localized: "Bills on your schedule", comment: "Paywall headline: custom recurrence gate")
        case .charts:
            return String(localized: "See where your money goes", comment: "Paywall headline: charts gate")
        case .dataExport:
            return String(localized: "Your data, anywhere", comment: "Paywall headline: data export gate")
        case .hiddenBills:
            return String(localized: "Unlock all your bills", comment: "Paywall headline: hidden bills display cap")
        case .hiddenIncomes:
            return String(localized: "Unlock all your income", comment: "Paywall headline: hidden incomes display cap")
        case .settings:
            return String(localized: "Get the most out of Billo", comment: "Paywall headline: opened from Settings")
        }
    }

    private var subheadline: String {
        switch context {
        case .firstLaunch:
            return String(localized: "Unlock everything with Billo Pro. Cancel anytime.", comment: "Paywall subheadline: first launch")
        case .billLimit:
            return String(localized: "Track unlimited bills with Billo Pro.", comment: "Paywall subheadline: free bill limit reached")
        case .incomeLimit:
            return String(localized: "Track unlimited income sources with Billo Pro.", comment: "Paywall subheadline: free income limit reached")
        case .partialPayment:
            return String(localized: "Record partial payments with Billo Pro.", comment: "Paywall subheadline: partial payment gate")
        case .customRecurrence:
            return String(localized: "Custom repeat intervals with Billo Pro.", comment: "Paywall subheadline: custom recurrence gate")
        case .charts:
            return String(localized: "Unlock spending insights with Billo Pro.", comment: "Paywall subheadline: charts gate")
        case .dataExport:
            return String(localized: "Export everything with Billo Pro.", comment: "Paywall subheadline: data export gate")
        case .hiddenBills:
            return String(localized: "Your data is safe — see every bill again with Billo Pro.", comment: "Paywall subheadline: hidden bills display cap")
        case .hiddenIncomes:
            return String(localized: "Your data is safe — see every income again with Billo Pro.", comment: "Paywall subheadline: hidden incomes display cap")
        case .settings:
            return String(localized: "Unlock everything with Billo Pro. Cancel anytime.", comment: "Paywall subheadline: opened from Settings")
        }
    }

    private func purchaseSelected() async {
        guard let product = storeKit.products.first(where: { $0.id == selectedProductID }) else { return }

        let planId = selectedPlan.analyticsPlanId
        Logger.log("Paywall purchase started (productID: \(product.id))", level: .info)
        analytics.capture(.paywallPurchaseAttempted(planId: planId, context: analyticsContext))
        isPurchasing = true
        defer { isPurchasing = false }

        let result = await storeKit.purchase(product)
        switch result {
        case .success:
            Logger.log("Paywall purchase success (productID: \(product.id))", level: .info)
            analytics.capture(.paywallPurchaseSucceeded(planId: planId, context: analyticsContext))
            finish(.purchased)

        case .failure(let error):
            Logger.log("Paywall purchase failed (productID: \(product.id), error: \(error))", level: .warning)
            switch error {
            case .cancelled:
                analytics.capture(.paywallPurchaseCancelled(planId: planId, context: analyticsContext))
            case .pending:
                analytics.capture(.paywallPurchasePending(planId: planId, context: analyticsContext))
            case .unverified, .unknown, .failed:
                // Stable, locale-independent reason key; detailed message
                // stays in the on-device log/alert.
                analytics.capture(.paywallPurchaseFailed(
                    planId: planId,
                    context: analyticsContext,
                    error: error.analyticsReason
                ))
            }
            if error != .cancelled {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var analyticsContext: String {
        context.analyticsKey
    }

    private func finish(_ result: PaywallResult) {
        didFinish = true
        switch result {
        case .purchased:
            break
        case .dismissed:
            Logger.log("Paywall dismissed", level: .info)
            analytics.capture(.paywallClosed(context: analyticsContext))
        }

        onFinished(result)
        if dismissOnFinish {
            dismiss()
        }
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
        let monthlyPrice = monthlyProduct?.price ?? FallbackPricing.monthlyPrice
        let yearlyPrice = yearlyProduct?.price ?? FallbackPricing.yearlyPrice

        guard let percent = PaywallPricing.savingsPercentage(monthlyPrice: monthlyPrice, yearlyPrice: yearlyPrice) else { return nil }
        return "SAVE \(percent)%"
    }
}

private enum SelectedPlan: Hashable {
    case monthly
    case yearly
    case lifetime

    var productID: String {
        switch self {
        case .monthly:
            return StoreKitManager.ProductID.monthly
        case .yearly:
            return StoreKitManager.ProductID.yearly
        case .lifetime:
            return StoreKitManager.ProductID.lifetime
        }
    }

    var purchaseButtonTitle: String {
        switch self {
        case .monthly, .yearly:
            return "Unlock Billo Pro"
        case .lifetime:
            return "Get Lifetime Access"
        }
    }

    var analyticsPlanId: String {
        switch self {
        case .monthly: "monthly"
        case .yearly: "yearly"
        case .lifetime: "lifetime"
        }
    }
}

private struct BenefitRow: View {
    let icon: String
    // LocalizedStringKey so literals at call sites extract into Localizable.xcstrings.
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.mediumSmall) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 32, height: 32)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                .accessibilityHidden(true)

            Text(text)
                .font(.subheadline.weight(.medium))

            Spacer(minLength: 0)
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
                                .background(.tint, in: Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ZStack {
                    if isSelected {
                        Circle()
                            .stroke(.tint, lineWidth: 2)
                            .frame(width: 24, height: 24)
                        Circle()
                            .fill(.tint)
                            .frame(width: 16, height: 16)
                    } else {
                        Circle()
                            .stroke(DesignSystem.Color.separator, lineWidth: 2)
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .padding(DesignSystem.Spacing.medium)
            .background(
                isSelected ? AnyShapeStyle(.tint.opacity(0.1)) : AnyShapeStyle(.regularMaterial),
                in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG && targetEnvironment(simulator)
#Preview {
    let storeKit = StoreKitManager(isPro: false)
    return PaywallView(context: .firstLaunch, isDismissible: true, dismissOnFinish: true, onFinished: { _ in })
        .environment(storeKit)
        .environment(AnalyticsModel())
}
#endif
