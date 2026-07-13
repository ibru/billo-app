//  Created by Jiri Urbasek on 11/28/25.

import Testing
import SwiftData
import Foundation
@testable import Billo

@Suite("Bill - Partial Payments") @MainActor
struct BillPartialPaymentsTests {

    @Test func whenPartialPayment_thenHasPaymentReturnsTrueButNotFullyPaid() throws {
        let (bill, context) = try makeSUT(amount: 100)
        let occurrence = bill.dueDate

        _ = makePaymentEntry(
            amount: 50,
            datePaid: Date(),
            occurrenceDate: occurrence,
            bill: bill,
            in: context
        )
        try context.save()

        #expect(bill.hasPayment(for: occurrence, calendar: .current))
        #expect(!bill.isFullyPaid(for: occurrence, calendar: .current))
        #expect(bill.totalPaid(for: occurrence, calendar: .current) == 50)
        #expect(bill.remainingBalance(for: occurrence, calendar: .current) == 50)
    }

    @Test func whenTwoPartialsSumToFull_thenIsFullyPaidReturnsTrue() throws {
        let (bill, context) = try makeSUT(amount: 100)
        let occurrence = bill.dueDate

        _ = makePaymentEntry(amount: 60, datePaid: Date(), occurrenceDate: occurrence, bill: bill, in: context)
        _ = makePaymentEntry(amount: 40, datePaid: Date(), occurrenceDate: occurrence, bill: bill, in: context)
        try context.save()

        #expect(bill.hasPayment(for: occurrence, calendar: .current))
        #expect(bill.isFullyPaid(for: occurrence, calendar: .current))
        #expect(bill.totalPaid(for: occurrence, calendar: .current) == 100)
        #expect(bill.remainingBalance(for: occurrence, calendar: .current) == 0)
    }

    @Test func whenOverpaid_thenIsFullyPaidTrueAndRemainingZero() throws {
        let (bill, context) = try makeSUT(amount: 100)
        let occurrence = bill.dueDate

        _ = makePaymentEntry(
            amount: 150,
            datePaid: Date(),
            occurrenceDate: occurrence,
            bill: bill,
            in: context
        )
        try context.save()

        #expect(bill.hasPayment(for: occurrence, calendar: .current))
        #expect(bill.isFullyPaid(for: occurrence, calendar: .current))
        #expect(bill.totalPaid(for: occurrence, calendar: .current) == 150)
        #expect(bill.remainingBalance(for: occurrence, calendar: .current) == 0)
    }

    @Test func whenPartialPaymentExists_thenOccurrenceRemainsInUnpaidList() throws {
        let (bill, context) = try makeSUT(amount: 100)
        let occurrence = bill.dueDate

        _ = makePaymentEntry(
            amount: 40,
            datePaid: Date(),
            occurrenceDate: occurrence,
            bill: bill,
            in: context
        )
        try context.save()

        let unpaid = bill.unpaidOccurrences(aroundDate: Date(), calendar: .current)

        #expect(unpaid.contains(occurrence), "Partially-paid occurrence should remain in unpaid list")
    }

    @Test func whenPartialPayment_thenStatusIsPartiallyPaid() throws {
        let (bill, context) = try makeSUT(amount: 100)
        let occurrence = bill.dueDate

        _ = makePaymentEntry(
            amount: 40,
            datePaid: Date(),
            occurrenceDate: occurrence,
            bill: bill,
            in: context
        )
        try context.save()

        let status = BillOccurrence(bill: bill, dueDate: occurrence)
            .status(relativeTo: Date(), calendar: .current)

        #expect(status == .partiallyPaid)
    }

    @Test func whenOccurrenceFrozenAtHigherAmountThanSeries_thenRemainingBalanceUsesFrozenAmount() throws {
        // A frozen occurrence still owes its snapshot amount even after the
        // series amount is edited downward. The mark-paid default must follow
        // the occurrence's remaining balance, never the live series amount —
        // otherwise a free user's untouched default reads as a partial payment.
        let (bill, context) = try makeSUT(amount: 120)
        let occurrence = bill.dueDate

        _ = makeIssuedOccurrence(for: bill, dueDate: occurrence, in: context)
        bill.amount = 100
        try context.save()

        #expect(bill.expectedAmount(for: occurrence, calendar: .current) == 120)
        #expect(bill.remainingBalance(for: occurrence, calendar: .current) == 120)
    }

    @Test func whenFullyPaid_thenOccurrenceRemovedFromUnpaidList() throws {
        let (bill, context) = try makeSUT(amount: 100)
        let occurrence = bill.dueDate

        _ = makePaymentEntry(
            amount: 100,
            datePaid: Date(),
            occurrenceDate: occurrence,
            bill: bill,
            in: context
        )
        try context.save()

        let unpaid = bill.unpaidOccurrences(aroundDate: Date(), calendar: .current)

        #expect(!unpaid.contains(occurrence), "Fully-paid occurrence should be removed from unpaid list")
    }
}

// MARK: - makeSUT & Factories

private func makeSUT(amount: Decimal = 100) throws -> (Bill, ModelContext) {
    let schema = Schema([Bill.self, PaymentEntry.self, IssuedOccurrence.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    let context = ModelContext(container)

    let bill = Bill(
        name: "Test Bill",
        amount: amount,
        dueDate: Date()
    )

    context.insert(bill)
    try context.save()

    return (bill, context)
}
