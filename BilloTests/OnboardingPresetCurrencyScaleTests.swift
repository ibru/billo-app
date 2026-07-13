//  Created by Jiri Urbasek on 7/12/26.

import Foundation
import Testing
@testable import Billo

@Suite("OnboardingPresetCurrencyScale")
struct OnboardingPresetCurrencyScaleTests {
    @Test func whenCurrencyIsUSD_thenPresetAmountsAreUnchanged() {
        for preset in OnboardingBillPreset.all {
            #expect(preset.startingAmount(for: "USD") == preset.defaultAmount)
        }
    }

    @Test func whenCurrencyIsUnknown_thenBaseAmountIsUsed() {
        for preset in OnboardingBillPreset.all {
            #expect(preset.startingAmount(for: "XXX") == preset.defaultAmount)
        }
    }

    @Test func whenCurrencyIsCZK_thenRentScalesToRealisticRoundedMagnitude() {
        let rent = try! #require(OnboardingBillPreset.all.first { $0.id == "rent" })
        // 1200 × 18 = 21,600 → rounded to the nearest 1,000.
        #expect(rent.startingAmount(for: "CZK") == 22_000)
    }

    @Test func whenCurrencyIsJPY_thenSmallAndLargeAmountsRoundToNiceSteps() {
        let rent = try! #require(OnboardingBillPreset.all.first { $0.id == "rent" })
        let music = try! #require(OnboardingBillPreset.all.first { $0.id == "music" })
        // 1200 × 100 = 120,000 (already nice); 11 × 100 = 1,100 → nearest 100.
        #expect(rent.startingAmount(for: "JPY") == 120_000)
        #expect(music.startingAmount(for: "JPY") == 1_100)
    }

    @Test(arguments: [
        (Decimal(21_600), Decimal(22_000)),   // nearest 1,000
        (Decimal(198), Decimal(200)),         // nearest 10
        (Decimal(9.35), Decimal(9)),          // nearest 1
        (Decimal(13.5), Decimal(14)),         // nearest 1
        (Decimal(1_080_000), Decimal(1_100_000)), // nearest 100,000
        (Decimal(4_820_000), Decimal(4_800_000)), // nearest 100,000
        (Decimal(370), Decimal(350)),         // nearest 50
    ])
    func whenRoundingScaledValues_thenTheyLandOnNiceSteps(value: Decimal, expected: Decimal) {
        #expect(OnboardingPresetCurrencyScale.niceRounded(value) == expected)
    }

    @Test func whenScaledAmountWouldRoundToZero_thenMinimumIsOne() {
        #expect(OnboardingPresetCurrencyScale.amount(fromUSDBase: 0.4, currencyCode: "USD") == 1)
    }

    @Test func whenScalingEveryKnownCurrency_thenAllPresetAmountsStayPositive() {
        for currencyCode in OnboardingPresetCurrencyScale.scales.keys {
            for preset in OnboardingBillPreset.all {
                #expect(preset.startingAmount(for: currencyCode) > 0, "\(preset.id) in \(currencyCode)")
            }
        }
    }

    @Test func whenScalingEveryKnownCurrency_thenRelativeOrderOfPresetsIsPreserved() {
        // Rent must always cost more than streaming — rounding must never
        // invert the obvious price relationships users sanity-check first.
        let rent = try! #require(OnboardingBillPreset.all.first { $0.id == "rent" })
        let streaming = try! #require(OnboardingBillPreset.all.first { $0.id == "streaming" })
        for currencyCode in OnboardingPresetCurrencyScale.scales.keys {
            #expect(rent.startingAmount(for: currencyCode) > streaming.startingAmount(for: currencyCode))
        }
    }
}
