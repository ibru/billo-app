//  Created by Jiri Urbasek on 7/10/26.

import Foundation

/// Decides whether onboarding should end early because CloudKit-synced data
/// from a previous install (or another device) arrived while the flow is on
/// screen. Complements the one-shot check at launch in `BilloApp` — this
/// policy is evaluated reactively as the production store changes mid-flow.
nonisolated struct ReturningUserSkipPolicy {
    /// - Parameters:
    ///   - hasSyncedBills: bills exist in the production store.
    ///   - hasSyncedCurrency: `AppSettings.currencyCode` is set in the production store.
    ///   - didSetCurrencyLocally: the user picked a currency in THIS flow — the
    ///     currency signal is then our own write, not evidence of a returning user.
    ///   - didCommitLocalSetup: this flow already committed its drafted bills —
    ///     the bills signal is then our own write.
    ///   - currentStep: skipping is suppressed on purchase screens so the UI
    ///     is never yanked away mid-transaction.
    func shouldSkipOnboarding(
        hasSyncedBills: Bool,
        hasSyncedCurrency: Bool,
        didSetCurrencyLocally: Bool,
        didCommitLocalSetup: Bool,
        currentStep: OnboardingStep
    ) -> Bool {
        guard !didCommitLocalSetup else { return false }
        guard currentStep != .paywall, currentStep != .thankYou else { return false }

        if hasSyncedBills { return true }
        if hasSyncedCurrency && !didSetCurrencyLocally { return true }
        return false
    }
}
