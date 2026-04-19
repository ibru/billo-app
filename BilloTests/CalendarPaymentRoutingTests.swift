//  Created by Jiri Urbasek on 04/19/26.

import Foundation
import SwiftData
import Testing
@testable import Billo

@MainActor
@Suite("CalendarPaymentRouting.destination(for:)")
struct CalendarPaymentRoutingTests {
    @Test
    func whenPaymentBillIsLive_thenRoutesToBillDetail() throws {
        let (payment, bill, _) = try makeLivePayment()

        let destination = CalendarPaymentRouting.destination(for: payment)

        #expect(destination == .bill(bill.persistentModelID))
    }

    @Test
    func whenPaymentBillWasDeleted_thenRoutesToOccurrenceDetail() throws {
        let (payment, occurrence) = try makeOrphanPayment()

        let destination = CalendarPaymentRouting.destination(for: payment)

        #expect(destination == .occurrence(occurrence.persistentModelID))
    }

    @Test
    func whenPaymentHasNoOccurrenceOrBill_thenRoutesToNothing() {
        let payment = makeDetachedPayment()

        let destination = CalendarPaymentRouting.destination(for: payment)

        #expect(destination == nil)
    }
}

// MARK: - makeSUT & Factories

@MainActor
private func makeContext() throws -> ModelContext {
    let schema = Schema([Bill.self, PaymentEntry.self, IssuedOccurrence.self])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    return ModelContext(container)
}

@MainActor
private func makeLivePayment(
    billName: String = "Internet",
    amount: Decimal = 50,
    dueDate: Date = Date()
) throws -> (PaymentEntry, Bill, ModelContext) {
    let context = try makeContext()
    let bill = Bill(name: billName, amount: amount, dueDate: dueDate)
    context.insert(bill)
    let payment = makePaymentEntry(
        amount: amount,
        datePaid: dueDate,
        occurrenceDate: dueDate,
        bill: bill,
        in: context
    )
    try context.save()
    return (payment, bill, context)
}

@MainActor
private func makeOrphanPayment(
    amount: Decimal = 50,
    dueDate: Date = Date()
) throws -> (PaymentEntry, IssuedOccurrence) {
    let context = try makeContext()
    let payment = try makeOrphanPaymentEntry(
        amount: amount,
        datePaid: dueDate,
        occurrenceDate: dueDate,
        in: context
    )
    let occurrence = try #require(payment.issuedOccurrence)
    return (payment, occurrence)
}

@MainActor
private func makeDetachedPayment(amount: Decimal = 10, datePaid: Date = Date()) -> PaymentEntry {
    PaymentEntry(
        amount: amount,
        datePaid: datePaid,
        confirmationNumber: nil,
        issuedOccurrence: nil
    )
}
