//  Created by Jiri Urbasek on 12/28/25.

import SwiftUI

struct AppRootView: View {
    @Environment(AppFlowModel.self) private var flow
    @Environment(AppSettingsModel.self) private var appSettingsModel
    @Environment(StoreKitManager.self) private var storeKit

    private let paywallPolicy = FirstLaunchPaywallPolicy()

    var body: some View {
        Group {
            if flow.didCompleteOnboarding == false {
                OnboardingFlowView(
                    paywallPolicy: paywallPolicy,
                    onFinish: { flow.completeOnboarding() }
                )
            } else {
                mainAppFlow
            }
        }
        .tint(DesignSystem.Color.green)
        .animation(.spring(duration: 0.35), value: flow.didCompleteOnboarding)
    }

    @ViewBuilder
    private var mainAppFlow: some View {
        if appSettingsModel.currencyCode == nil {
            CurrencyOnboardingView()
        } else {
            BillsHomeSwitchView()
        }
    }
}

#if DEBUG && targetEnvironment(simulator)
#Preview {
    let preview = BilloPreviewContainer.empty()
    let previewDefaults = UserDefaults(suiteName: "preview-root") ?? .standard
    let flow = AppFlowModel(persistence: AppPersistence(defaults: previewDefaults))
    let storeKit = StoreKitManager(isPro: false)

    return AppRootView()
        .environment(preview.billsModel)
        .environment(preview.notificationCoordinator)
        .environment(preview.preferencesStore)
        .environment(preview.appSettingsModel)
        .environment(flow)
        .environment(storeKit)
        .environment(AnalyticsModel())
        // Unique suite per render — a fixed one would persist review-prompt
        // counters on the dev machine across preview sessions.
        .environment(ReviewPromptModel(
            persistence: AppPersistence(defaults: UserDefaults(suiteName: "preview-reviews-\(UUID().uuidString)") ?? .standard)
        ))
}
#endif
