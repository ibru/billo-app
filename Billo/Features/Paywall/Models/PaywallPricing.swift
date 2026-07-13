//  Created by Jiri Urbasek on 12/29/25.

import Foundation

enum PaywallPricing {
    nonisolated static func savingsPercentage(monthlyPrice: Decimal, yearlyPrice: Decimal) -> Int? {
        guard monthlyPrice > 0 else { return nil }

        let yearlyFromMonthly = monthlyPrice * 12
        guard yearlyFromMonthly > 0 else { return nil }

        let savings = ((yearlyFromMonthly - yearlyPrice) / yearlyFromMonthly) * 100
        let rounded = Int(NSDecimalNumber(decimal: savings).doubleValue.rounded())
        return rounded > 0 ? rounded : nil
    }
}
