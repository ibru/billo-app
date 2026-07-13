//  Created by Jiri Urbasek on 7/13/26.

import SwiftUI

extension View {
    /// Presents the shared Pro paywall when a feature gate sets a context.
    /// Post-purchase behavior is deliberately "repeat the action": the sheet
    /// dismisses, `isPro` flips reactively, and the user redoes the blocked
    /// action once — no auto-retry plumbing back into gate sites.
    func paywallSheet(context: Binding<PaywallContext?>) -> some View {
        sheet(item: context) { presentedContext in
            PaywallView(
                context: presentedContext,
                isDismissible: true,
                dismissOnFinish: true,
                onFinished: { _ in }
            )
        }
    }
}
