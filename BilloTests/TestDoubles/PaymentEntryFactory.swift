//  Created by Jiri Urbasek on 01/26/26.

import Foundation
import SwiftData
@testable import Billo

@MainActor
func makeIssuedOccurrence(
    for bill: Bill,
    dueDate: Date,
    calendar: Calendar = .current,
    in context: ModelContext
) -> IssuedOccurrence {
    if let existing = bill.issuedOccurrence(for: dueDate, calendar: calendar) {
        return existing
    }

    let issued = IssuedOccurrence(
        occurrenceKey: bill.occurrenceKey(for: dueDate, calendar: calendar),
        dueDate: dueDate,
        billName: bill.name,
        billAmount: bill.amount,
        billCurrencyCode: bill.currencyCode,
        billAccountIdentifier: bill.accountIdentifier,
        billNotes: bill.notes,
        billCategoryRawValue: bill.categoryIdentifier?.rawValue,
        bill: bill
    )
    context.insert(issued)
    return issued
}

@MainActor
func makePaymentEntry(
    amount: Decimal,
    datePaid: Date,
    occurrenceDate: Date,
    bill: Bill,
    calendar: Calendar = .current,
    in context: ModelContext
) -> PaymentEntry {
    let issued = makeIssuedOccurrence(for: bill, dueDate: occurrenceDate, calendar: calendar, in: context)
    let payment = PaymentEntry(
        amount: amount,
        datePaid: datePaid,
        confirmationNumber: nil,
        issuedOccurrence: issued
    )
    context.insert(payment)
    return payment
}

/// Creates a payment whose originating Bill has been deleted, leaving the
/// IssuedOccurrence snapshot and PaymentEntry orphaned (bill reference nil).
///
/// Mirrors the production flow where `BillsModel.deleteBill` relies on
/// SwiftData's `.nullify` rule on `Bill.issuedOccurrences` to preserve history.
@MainActor
func makeOrphanPaymentEntry(
    amount: Decimal,
    datePaid: Date,
    occurrenceDate: Date,
    billName: String = "Deleted Bill",
    billAmount: Decimal? = nil,
    calendar: Calendar = .current,
    in context: ModelContext
) throws -> PaymentEntry {
    let bill = Bill(
        name: billName,
        amount: billAmount ?? amount,
        dueDate: occurrenceDate,
        calendar: calendar
    )
    context.insert(bill)
    let payment = makePaymentEntry(
        amount: amount,
        datePaid: datePaid,
        occurrenceDate: occurrenceDate,
        bill: bill,
        calendar: calendar,
        in: context
    )
    try context.save()
    context.delete(bill)
    try context.save()
    return payment
}
