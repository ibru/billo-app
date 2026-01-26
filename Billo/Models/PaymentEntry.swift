//  Created by Jiri Urbasek on 11/26/25.

import SwiftData
import Foundation

@Model
final class PaymentEntry {
    var amount: Decimal = 0
    var datePaid: Date = Date()
    var confirmationNumber: String?
    var notes: String?
    var createdDate: Date = Date()

    var issuedOccurrence: IssuedOccurrence?

    init(
        amount: Decimal,
        datePaid: Date,
        confirmationNumber: String? = nil,
        notes: String? = nil,
        issuedOccurrence: IssuedOccurrence? = nil
    ) {
        self.amount = amount
        self.datePaid = datePaid
        self.confirmationNumber = confirmationNumber
        self.notes = notes
        self.issuedOccurrence = issuedOccurrence
        self.createdDate = Date()
    }
}

extension PaymentEntry {
    var occurrenceDate: Date {
        issuedOccurrence?.dueDate ?? datePaid
    }

    var bill: Bill? {
        issuedOccurrence?.bill
    }

    var snapshotName: String? {
        issuedOccurrence?.billName
    }

    var snapshotAmount: Decimal? {
        issuedOccurrence?.billAmount
    }

    var snapshotCurrencyCode: String? {
        issuedOccurrence?.billCurrencyCode
    }

    var snapshotAccountIdentifier: String? {
        issuedOccurrence?.billAccountIdentifier
    }

    var snapshotNotes: String? {
        issuedOccurrence?.billNotes
    }

    var snapshotCategoryIdentifier: CategoryIdentifier? {
        issuedOccurrence?.billCategoryIdentifier
    }
}
