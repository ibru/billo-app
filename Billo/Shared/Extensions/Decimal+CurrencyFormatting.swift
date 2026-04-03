//  Created by Jiri Urbasek on 04/03/26.

import Foundation

extension Decimal {
    func formattedAsCurrency(code: String, locale: Locale = .autoupdatingCurrent) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = locale
        return formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
    }
}
