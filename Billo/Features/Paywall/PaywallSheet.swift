//  Created by Jiri Urbasek on 7/13/26.

import StoreKit
import SwiftUI

extension View {
    /// Presents the shared Pro paywall when a feature gate sets a context.
    /// Post-purchase behavior is deliberately "repeat the action": the sheet
    /// dismisses, `isPro` flips reactively, and the user redoes the blocked
    /// action once — no auto-retry plumbing back into gate sites.
    ///
    /// A purchase is also a review-prompt moment: shortly after the sheet
    /// dismisses, the system rating dialog is requested via
    /// `ReviewPromptModel` (iOS decides whether it shows) — kept out of the
    /// purchase flow itself so the "repeat the action" continuity stays
    /// instant.
    func paywallSheet(context: Binding<PaywallContext?>) -> some View {
        modifier(PaywallSheetModifier(context: context))
    }
}

private struct PaywallSheetModifier: ViewModifier {
    @Environment(\.requestReview) private var requestReview
    @Environment(ReviewPromptModel.self) private var reviewPrompts
    @Environment(StoreKitManager.self) private var storeKit
    @Environment(AnalyticsModel.self) private var analytics

    @Binding var context: PaywallContext?
    @State private var didPurchase = false

    func body(content: Content) -> some View {
        content.sheet(item: $context, onDismiss: handleDismiss) { presentedContext in
            PaywallView(
                context: presentedContext,
                isDismissible: true,
                dismissOnFinish: true,
                onFinished: { result in
                    if result == .purchased {
                        didPurchase = true
                    }
                }
            )
            // Mac Catalyst drops @Observable environment values at the sheet
            // boundary (see AppEnvironmentModels) — re-inject what
            // PaywallView reads. Captured here, at the presenting level,
            // where the environment is intact.
            .environment(storeKit)
            .environment(analytics)
        }
    }

    private func handleDismiss() {
        guard didPurchase else { return }
        didPurchase = false
        guard reviewPrompts.notePaywallPurchaseCompleted() else { return }
        Task {
            await requestReview.requestAfterSettleDelay()
        }
    }
}
