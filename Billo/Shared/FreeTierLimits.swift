//  Created by Jiri Urbasek on 7/13/26.

import Foundation

/// Single home for every free-tier gate rule. Pure functions so gate decisions
/// are unit-testable without StoreKit or SwiftData. The market-research hard
/// rules behind these numbers: data is never deleted or locked — over-cap
/// items are hidden from display (soonest-due stay visible) and reappear on
/// upgrade or when deletions free a slot; historical records (payments,
/// frozen income snapshots) always stay visible. The free tier must support
/// a full household setup before any paywall appears.
nonisolated enum FreeTierLimits {
    /// Stored `Bill` records (one per series). Deliberately generous —
    /// low caps (3–5) are the #1 "fake free tier" 1★ driver in competitor
    /// reviews. Deleting a bill frees a slot.
    static let billLimit = 12

    static func canAddBill(currentCount: Int, isPro: Bool) -> Bool {
        isPro || currentCount < billLimit
    }

    /// Stored `Income` records. Two covers the typical household (salary +
    /// one side income); more is a power-user scale gate.
    static let incomeLimit = 2

    static func canAddIncome(currentCount: Int, isPro: Bool) -> Bool {
        isPro || currentCount < incomeLimit
    }

    /// Display-cap overflow: how many stored items exceed the free-tier limit
    /// and are therefore hidden from display for non-Pro users.
    static func hiddenCount(totalCount: Int, limit: Int, isPro: Bool) -> Int {
        isPro ? 0 : max(0, totalCount - limit)
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
