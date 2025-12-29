//  Created by Jiri Urbasek on 12/29/25.

import SwiftUI

struct FirstLaunchFlowView: View {
    @Environment(AppFlowModel.self) private var flow
    @Environment(AppSettingsModel.self) private var appSettingsModel
    @Environment(StoreKitManager.self) private var storeKit

    let paywallPolicy: FirstLaunchPaywallPolicy
    let onFinish: () -> Void

    @State private var path: [FirstLaunchStep] = []

    private var firstStep: FirstLaunchStep { orderedSteps[0] }

    var body: some View {
        NavigationStack(path: $path) {
            stepView(for: firstStep)
                .navigationBarBackButtonHidden(true)
                .navigationDestination(for: FirstLaunchStep.self) { step in
                    stepView(for: step)
                        .navigationBarBackButtonHidden(true)
                }
        }
    }

    // MARK: - Steps

    private enum FirstLaunchStep: Hashable {
        case marketing1
        case marketing2
        case marketing3
        case marketing4
        case currency
        case paywall
        case thankYou
    }

    /// Reorder/add/remove here to change the onboarding flow.
    private var orderedSteps: [FirstLaunchStep] {
        [
            .marketing1,
            .marketing2,
            .marketing3,
            .marketing4,
            .currency,
            .paywall,
        ]
    }

    private func nextStep(after step: FirstLaunchStep) -> FirstLaunchStep? {
        guard let index = orderedSteps.firstIndex(of: step) else { return nil }
        let nextIndex = index + 1
        guard orderedSteps.indices.contains(nextIndex) else { return nil }
        return orderedSteps[nextIndex]
    }

    private func goToNext(after step: FirstLaunchStep) {
        guard let next = nextStep(after: step) else {
            Logger.log("First-launch flow finished (no next step)", level: .info)
            onFinish()
            return
        }
        Logger.log("First-launch flow step: \(String(describing: step)) → \(String(describing: next))", level: .debug)
        path.append(next)
    }

    // MARK: - Step Views

    @ViewBuilder
    private func stepView(for step: FirstLaunchStep) -> some View {
        switch step {
        case .marketing1:
            FirstLaunchMarketingStep1View(onContinue: { goToNext(after: .marketing1) })

        case .marketing2:
            FirstLaunchMarketingStep2View(onContinue: { goToNext(after: .marketing2) })

        case .marketing3:
            FirstLaunchMarketingStep3View(onContinue: { goToNext(after: .marketing3) })

        case .marketing4:
            FirstLaunchMarketingStep4View(onContinue: { goToNext(after: .marketing4) })

        case .currency:
            FirstLaunchCurrencyStepView(onContinue: {
                handleCurrencyFinished()
            })

        case .paywall:
            PaywallView(
                context: .firstLaunch,
                isDismissible: true,
                dismissOnFinish: false,
                onFinished: handleFirstLaunchPaywallFinished
            )

        case .thankYou:
            PurchaseThankYouView(onContinue: onFinish)
        }
    }

    private func handleCurrencyFinished() {
        guard appSettingsModel.currencyCode != nil else { return }

        Logger.log("First-launch currency set, evaluating paywall", level: .info)
        if storeKit.isPro {
            flow.markFirstLaunchPaywallShown()
            onFinish()
            return
        }

        let shouldShowPaywall = paywallPolicy.shouldShowPaywallAfterOnboarding(
            entitlementIsPro: storeKit.isPro,
            didShowFirstLaunchPaywall: flow.didShowFirstLaunchPaywall
        )

        if shouldShowPaywall {
            Logger.log("First-launch paywall will be shown", level: .info)
            path.append(.paywall)
        } else {
            Logger.log("First-launch paywall skipped by policy", level: .info)
            onFinish()
        }
    }

    private func handleFirstLaunchPaywallFinished(_ result: PaywallResult) {
        flow.markFirstLaunchPaywallShown()

        switch result {
        case .purchased:
            Logger.log("First-launch paywall result: purchased", level: .info)
            path.append(.thankYou)
        case .dismissed:
            Logger.log("First-launch paywall result: dismissed", level: .info)
            onFinish()
        }
    }
}

#if DEBUG && targetEnvironment(simulator)
#Preview {
    let preview = BilloPreviewContainer.empty()
    let flow = AppFlowModel(persistence: AppPersistence(defaults: UserDefaults(suiteName: "preview-first-launch") ?? .standard))
    let storeKit = StoreKitManager()

    return FirstLaunchFlowView(paywallPolicy: FirstLaunchPaywallPolicy(), onFinish: {})
        .environment(preview.billsModel)
        .environment(preview.notificationCoordinator)
        .environment(preview.preferencesStore)
        .environment(preview.appSettingsModel)
        .environment(flow)
        .environment(storeKit)
}
#endif
