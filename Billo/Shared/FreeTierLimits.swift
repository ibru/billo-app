//  Created by Jiri Urbasek on 7/13/26.

import Foundation

/// Single home for every free-tier gate rule. Pure functions so gate decisions
/// are unit-testable without StoreKit or SwiftData. The market-research hard
/// rules behind these numbers: existing data is never hidden or blocked (gates
/// apply only to *new* actions), and the free tier must support a full
/// household setup before any paywall appears.
nonisolated enum FreeTierLimits {
    /// Stored `Bill` records (one per series). Deliberately generous —
    /// low caps (3–5) are the #1 "fake free tier" 1★ driver in competitor
    /// reviews. Deleting a bill frees a slot.
    static let billLimit = 15

    static func canAddBill(currentCount: Int, isPro: Bool) -> Bool {
        isPro || currentCount < billLimit
    }

    /// Stored `Income` records. Two covers the typical household (salary +
    /// one side income); more is a power-user scale gate.
    static let incomeLimit = 2

    static func canAddIncome(currentCount: Int, isPro: Bool) -> Bool {
        isPro || currentCount < incomeLimit
    }

    /// Partial = paying less than what is still owed on the occurrence.
    /// Full payment and overpayment stay free at any tier.
    static func canRecordPayment(amount: Decimal, remainingBalance: Decimal, isPro: Bool) -> Bool {
        isPro || amount >= remainingBalance
    }

    static func canSelectCustomRecurrence(isPro: Bool) -> Bool { isPro }
    static func canViewCharts(isPro: Bool) -> Bool { isPro }
    static func canExportData(isPro: Bool) -> Bool { isPro }
}
