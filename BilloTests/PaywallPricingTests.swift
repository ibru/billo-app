//  Created by Jiri Urbasek on 12/29/25.

import Foundation
import Testing
@testable import Billo

@Suite("PaywallPricing")
struct PaywallPricingTests {
    @Test func whenYearlyIsCheaperThanWeeklyAnnual_thenReturnsPositiveSavingsPercentage() async throws {
        let percent = try #require(PaywallPricing.savingsPercentage(weeklyPrice: 4, yearlyPrice: 100))

        #expect(percent > 0)
    }

    @Test func whenYearlyIsMoreExpensiveThanWeeklyAnnual_thenReturnsNil() async throws {
        let percent = PaywallPricing.savingsPercentage(weeklyPrice: 2, yearlyPrice: 200)

        #expect(percent == nil)
    }

    @Test func whenWeeklyPriceIsZero_thenReturnsNil() async throws {
        let percent = PaywallPricing.savingsPercentage(weeklyPrice: 0, yearlyPrice: 10)

        #expect(percent == nil)
    }

    @Test func whenIntroOfferIsThreeDays_thenFormatsPluralCorrectly() async throws {
        let text = PaywallPricing.introductoryOfferText(value: 3, unit: .day)

        #expect(text == "3 days free")
    }

    @Test func whenIntroOfferIsOneWeek_thenFormatsSingularCorrectly() async throws {
        let text = PaywallPricing.introductoryOfferText(value: 1, unit: .week)

        #expect(text == "1 week free")
    }

    @Test func whenIntroOfferValueIsZero_thenReturnsEmptyString() async throws {
        let text = PaywallPricing.introductoryOfferText(value: 0, unit: .day)

        #expect(text.isEmpty)
    }
}
