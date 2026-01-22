//  Created by Jiri Urbasek on 11/26/25.

import SwiftData
import Foundation

@Model
final class Payment {
    var amount: Decimal = 0
    var datePaid: Date = Date()
    var occurrenceDate: Date = Date()
    var confirmationNumber: String?
    var notes: String?
    var createdDate: Date = Date()

    var bill: Bill?

    init(
        amount: Decimal,
        datePaid: Date,
        occurrenceDate: Date,
        confirmationNumber: String? = nil,
        notes: String? = nil,
        bill: Bill? = nil
    ) {
        self.amount = amount
        self.datePaid = datePaid
        self.occurrenceDate = occurrenceDate
        self.confirmationNumber = confirmationNumber
        self.notes = notes
        self.bill = bill
        self.createdDate = Date()
    }
}
