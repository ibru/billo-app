//  Created by Jiri Urbasek on 7/15/26.

import Testing
import Foundation
@testable import Billo

@MainActor
@Suite("StoreKitManager active plan")
struct StoreKitManagerActivePlanTests {

    @Test func whenEntitlementAppliedWithPlan_thenIsProTrueAndPlanExposed() {
        let sut = makeSUT()

        sut.applyEntitlement(activePlan: .yearly)

        #expect(sut.isPro == true)
        #expect(sut.activePlan == .yearly)
    }

    @Test func whenEntitlementAppliedWithNoPlan_thenIsProFalseAndPlanCleared() {
        let sut = makeSUT()
        sut.applyEntitlement(activePlan: .monthly)

        sut.applyEntitlement(activePlan: nil)

        #expect(sut.isPro == false)
        #expect(sut.activePlan == nil)
    }

    @Test func whenSeededFromCache_thenIsProTrueButPlanUnknown() {
        // The cache persists only the boolean — until the first entitlement
        // refresh lands, the plan is unknown and display falls back to "Active".
        let sut = StoreKitManager(cache: ProEntitlementCacheStub(isPro: true))

        #expect(sut.isPro == true)
        #expect(sut.activePlan == nil)
    }

    // MARK: - Product ID mapping

    @Test(arguments: [
        (StoreKitManager.ProductID.monthly, StoreKitManager.ProPlan.monthly),
        (StoreKitManager.ProductID.yearly, StoreKitManager.ProPlan.yearly),
        (StoreKitManager.ProductID.lifetime, StoreKitManager.ProPlan.lifetime)
    ])
    func whenProductIDKnown_thenPlanMapped(productID: String, expected: StoreKitManager.ProPlan) {
        #expect(StoreKitManager.ProPlan(productID: productID) == expected)
    }

    @Test func whenProductIDUnknown_thenNoPlanMapped() {
        #expect(StoreKitManager.ProPlan(productID: "com.other.app.pro") == nil)
    }

    // MARK: - Preference among concurrent entitlements

    @Test func whenMultiplePlansActive_thenLifetimeWinsOverSubscriptions() {
        let preferred = StoreKitManager.ProPlan.preferred(among: [.monthly, .lifetime, .yearly])

        #expect(preferred == .lifetime)
    }

    @Test func whenOnlySubscriptionsActive_thenYearlyWinsOverMonthly() {
        let preferred = StoreKitManager.ProPlan.preferred(among: [.monthly, .yearly])

        #expect(preferred == .yearly)
    }

    @Test func whenNoPlansActive_thenNoPreferredPlan() {
        #expect(StoreKitManager.ProPlan.preferred(among: []) == nil)
    }

    // MARK: - Helpers

    private func makeSUT() -> StoreKitManager {
        StoreKitManager(cache: ProEntitlementCacheStub(isPro: false))
    }
}

// MARK: - Stub

@MainActor
private final class ProEntitlementCacheStub: ProEntitlementCaching {
    private(set) var isPro: Bool

    init(isPro: Bool) {
        self.isPro = isPro
    }

    func save(isPro: Bool) {
        self.isPro = isPro
    }
}
