//  Created by Jiri Urbasek on 01/23/26.

import SwiftData
import Foundation

@Model
final class IssuedOccurrence {
    var occurrenceKey: String = ""
    var dueDate: Date = Date()

    var billName: String = ""
    var billAmount: Decimal = 0
    var billCurrencyCode: String = "USD"
    var billAccountIdentifier: String?
    var billNotes: String?
    var billCategoryRawValue: String?

    var createdDate: Date = Date()

    var bill: Bill?

    @Relationship(deleteRule: .cascade, inverse: \PaymentEntry.issuedOccurrence)
    var paymentEntries: [PaymentEntry]? = []

    init(
        occurrenceKey: String,
        dueDate: Date,
        billName: String,
        billAmount: Decimal,
        billCurrencyCode: String,
        billAccountIdentifier: String?,
        billNotes: String?,
        billCategoryRawValue: String?,
        bill: Bill?
    ) {
        self.occurrenceKey = occurrenceKey
        self.dueDate = dueDate
        self.billName = billName
        self.billAmount = billAmount
        self.billCurrencyCode = billCurrencyCode
        self.billAccountIdentifier = billAccountIdentifier
        self.billNotes = billNotes
        self.billCategoryRawValue = billCategoryRawValue
        self.bill = bill
        self.createdDate = Date()
    }
}

extension IssuedOccurrence {
    var safePaymentEntries: [PaymentEntry] {
        paymentEntries ?? []
    }

    /// Total amount paid across all payment entries for this occurrence.
    var totalPaid: Decimal {
        safePaymentEntries.reduce(0) { $0 + $1.amount }
    }

    /// Whether this occurrence is fully paid (totalPaid >= snapshot amount).
    /// Works correctly for orphaned occurrences (bill deleted) since it uses snapshot data.
    var isPaid: Bool {
        totalPaid >= billAmount
    }

    /// Remaining balance for this occurrence.
    var remainingBalance: Decimal {
        max(0, billAmount - totalPaid)
    }

    var billCategoryIdentifier: CategoryIdentifier? {
        billCategoryRawValue.flatMap(CategoryIdentifier.init(rawValue:))
    }
}
