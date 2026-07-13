//  Created by Jiri Urbasek on 12/29/25.

import Foundation
import Testing
@testable import Billo

@Suite("PaywallPricing")
struct PaywallPricingTests {
    @Test func whenYearlyIsCheaperThanMonthlyAnnual_thenReturnsPositiveSavingsPercentage() async throws {
        let percent = try #require(PaywallPricing.savingsPercentage(monthlyPrice: 3.99, yearlyPrice: 29.99))

        #expect(percent > 0)
    }

    @Test func whenYearlyIsCheaperThanMonthlyAnnual_thenRoundsToNearestPercent() async throws {
        // 12 × 10 = 120 vs 90 → exactly 25%
        let percent = try #require(PaywallPricing.savingsPercentage(monthlyPrice: 10, yearlyPrice: 90))

        #expect(percent == 25)
    }

    @Test func whenYearlyIsMoreExpensiveThanMonthlyAnnual_thenReturnsNil() async throws {
        let percent = PaywallPricing.savingsPercentage(monthlyPrice: 2, yearlyPrice: 200)

        #expect(percent == nil)
    }

    @Test func whenMonthlyPriceIsZero_thenReturnsNil() async throws {
        let percent = PaywallPricing.savingsPercentage(monthlyPrice: 0, yearlyPrice: 10)

        #expect(percent == nil)
    }
}
