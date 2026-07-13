//  Created by Jiri Urbasek on 7/13/26.

import Testing
import Foundation
@testable import Billo

@MainActor
@Suite("StoreKitManager Pro cache")
struct StoreKitManagerProCacheTests {

    @Test func whenCacheSaysPro_thenIsProSeededTrueBeforeEntitlementRefresh() {
        let (sut, _) = makeSUT(cachedIsPro: true)

        #expect(sut.isPro == true)
    }

    @Test func whenCacheSaysNotPro_thenIsProSeededFalse() {
        let (sut, _) = makeSUT(cachedIsPro: false)

        #expect(sut.isPro == false)
    }

    @Test func whenEntitlementAppliedActive_thenIsProTrueAndCacheSavedTrue() {
        let (sut, cache) = makeSUT(cachedIsPro: false)

        sut.applyEntitlement(isActive: true)

        #expect(sut.isPro == true)
        #expect(cache.savedValues == [true])
    }

    @Test func whenEntitlementAppliedInactive_thenIsProFalseAndCacheSavedFalse() {
        // Optimistic seed from a stale cache must be overwritten by the refresh.
        let (sut, cache) = makeSUT(cachedIsPro: true)

        sut.applyEntitlement(isActive: false)

        #expect(sut.isPro == false)
        #expect(cache.savedValues == [false])
    }

    // MARK: - Helpers

    private func makeSUT(cachedIsPro: Bool) -> (StoreKitManager, ProEntitlementCacheSpy) {
        let cache = ProEntitlementCacheSpy(isPro: cachedIsPro)
        let sut = StoreKitManager(cache: cache)
        return (sut, cache)
    }
}

// MARK: - Spy

@MainActor
private final class ProEntitlementCacheSpy: ProEntitlementCaching {
    private(set) var isPro: Bool
    private(set) var savedValues: [Bool] = []

    init(isPro: Bool) {
        self.isPro = isPro
    }

    func save(isPro: Bool) {
        self.isPro = isPro
        savedValues.append(isPro)
    }
}
