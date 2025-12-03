//  Created by Jiri Urbasek on 12/02/25.

import Foundation

/// Pure functions for building notification content - no side effects
/// Note: Requires @MainActor because String(localized:) requires main actor access
struct NotificationContentBuilder: Sendable {
    let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    /// Builds reminder body text based on amount and offset
    @MainActor
    func reminderBody(
        amount: Decimal,
        currencyCode: String,
        offsetDays: Int
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"

        switch offsetDays {
        case 0:
            return String(localized: "\(amountString) is due today")
        case 1:
            return String(localized: "\(amountString) is due tomorrow")
        default:
            return String(localized: "\(amountString) is due in \(offsetDays) days")
        }
    }

    /// Builds digest body, handling mixed currencies gracefully
    /// - Parameters:
    ///   - billCount: Number of bills due
    ///   - totalAmount: Total amount (nil if mixed currencies)
    ///   - currencyCode: Currency code (nil if mixed currencies)
    ///   - lookaheadDays: Lookahead window in days
    @MainActor
    func digestBody(
        billCount: Int,
        totalAmount: Decimal?,
        currencyCode: String?,
        lookaheadDays: Int
    ) -> String {
        let billsText = billCount == 1 ? "bill" : "bills"

        if let totalAmount, let currencyCode {
            // Single currency: show count and total
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currencyCode
            formatter.locale = locale
            let amountString = formatter.string(from: totalAmount as NSDecimalNumber) ?? "\(totalAmount)"
            return String(localized: "\(billCount) \(billsText) (\(amountString)) due in next \(lookaheadDays) days")
        } else {
            // Mixed currencies: count only
            return String(localized: "\(billCount) \(billsText) due in next \(lookaheadDays) days")
        }
    }
}
