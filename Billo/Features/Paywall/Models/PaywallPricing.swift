//  Created by Jiri Urbasek on 12/29/25.

import Foundation

enum PaywallPricing {
    enum SubscriptionUnit: Hashable, Sendable {
        case day
        case week
        case month
        case year
    }

    nonisolated static func savingsPercentage(weeklyPrice: Decimal, yearlyPrice: Decimal) -> Int? {
        guard weeklyPrice > 0 else { return nil }

        let yearlyFromWeekly = weeklyPrice * 52
        guard yearlyFromWeekly > 0 else { return nil }

        let savings = ((yearlyFromWeekly - yearlyPrice) / yearlyFromWeekly) * 100
        let rounded = Int(NSDecimalNumber(decimal: savings).doubleValue.rounded())
        return rounded > 0 ? rounded : nil
    }

    nonisolated static func introductoryOfferText(value: Int, unit: SubscriptionUnit) -> String {
        guard value > 0 else { return "" }
        let unitText = switch unit {
        case .day: "day"
        case .week: "week"
        case .month: "month"
        case .year: "year"
        }

        let plural = value == 1 ? "" : "s"
        return "\(value) \(unitText)\(plural) free"
    }
}
