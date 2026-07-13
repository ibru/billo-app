//  Created by Jiri Urbasek on 7/12/26.

import Foundation

/// Scales the USD-based preset amounts to a realistic order of magnitude for
/// other currencies, so the bill-setup chips don't show "45 CZK" for a phone
/// plan that actually costs ~800 Kč.
///
/// One factor per currency (not per bill): the factors are cost-of-living
/// informed estimates of typical local expense levels — deliberately NOT
/// market FX rates, and deliberately not a per-bill matrix (currency ≠
/// country, and these are editable defaults where only the magnitude has to
/// be right). Scaled values are rounded to "nice" local steps (22,000 Kč,
/// not 21,600 Kč). Unlisted currencies fall back to the USD magnitudes.
/// Review the table occasionally — especially high-inflation entries (TRY).
nonisolated enum OnboardingPresetCurrencyScale {
    static let scales: [String: Decimal] = [
        "USD": 1,
        "EUR": 0.9,
        "GBP": 0.85,
        "CHF": 1.4,

        "CZK": 18,
        "PLN": 2.8,
        "HUF": 220,
        "RON": 3,
        "SEK": 9,
        "NOK": 10,
        "DKK": 7,
        "UAH": 15,
        "TRY": 30,

        "JPY": 100,
        "CNY": 4,
        "KRW": 900,
        "HKD": 12,
        "SGD": 2.5,
        "TWD": 22,
        "THB": 12,
        "PHP": 15,
        "IDR": 4_000,
        "MYR": 2,
        "VND": 6_000,
        "INR": 20,

        "AUD": 1.6,
        "NZD": 1.7,
        "CAD": 1.5,

        "BRL": 2.5,
        "MXN": 12,
        "CLP": 400,
        "COP": 1_500,

        "ZAR": 8,
        "ILS": 3.5,
        "AED": 4,
        "SAR": 3,
    ]

    /// A USD-baseline amount expressed in `currencyCode`: scaled by the
    /// table factor and rounded to a natural local step, never below 1.
    static func amount(fromUSDBase baseAmount: Decimal, currencyCode: String) -> Decimal {
        guard let scale = scales[currencyCode] else { return baseAmount }
        return max(niceRounded(baseAmount * scale), 1)
    }

    /// Rounds to the step a person would naturally quote at that magnitude —
    /// scaled defaults must read like local prices, not like conversions.
    static func niceRounded(_ value: Decimal) -> Decimal {
        let step: Decimal =
            if value < 20 { 1 }
            else if value < 100 { 5 }
            else if value < 300 { 10 }
            else if value < 1_000 { 50 }
            else if value < 10_000 { 100 }
            else if value < 100_000 { 1_000 }
            else if value < 1_000_000 { 10_000 }
            else { 100_000 }

        var quotient = value / step
        var rounded = Decimal()
        NSDecimalRound(&rounded, &quotient, 0, .plain)
        return rounded * step
    }
}

extension OnboardingBillPreset {
    /// The chip/sheet starting amount in the user's currency. `defaultAmount`
    /// stays the USD baseline; this is what the UI should show. (Named
    /// distinctly from the property — same base name confuses overload
    /// resolution in Xcode's compiler front end.)
    func startingAmount(for currencyCode: String) -> Decimal {
        OnboardingPresetCurrencyScale.amount(fromUSDBase: defaultAmount, currencyCode: currencyCode)
    }
}
