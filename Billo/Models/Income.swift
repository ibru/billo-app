//  Created by Jiri Urbasek on 11/26/25.

import SwiftData
import Foundation

@Model
final class Income {
    var name: String
    var amount: Decimal
    var currencyCode: String
    var frequency: RepeatIntervalType
    var nextDate: Date
    var createdDate: Date
    var lastUpdatedDate: Date

    init(
        name: String,
        amount: Decimal,
        currencyCode: String = Locale.current.currency?.identifier ?? "USD",
        frequency: RepeatIntervalType,
        nextDate: Date
    ) {
        self.name = name
        self.amount = amount
        self.currencyCode = currencyCode
        self.frequency = frequency
        self.nextDate = nextDate
        self.createdDate = Date()
        self.lastUpdatedDate = Date()
    }
}
