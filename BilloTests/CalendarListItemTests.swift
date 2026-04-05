//  Created by Jiri Urbasek on 12/05/25.

import Testing
import SwiftData
import Foundation
@testable import Billo

@MainActor
@Suite("CalendarListItem")
struct CalendarListItemTests {
    @Test
    func when_billItem_then_dateReturnsDueDate() throws {
        let calendar = Calendar(identifier: .gregorian)
        let context = try makeContext()
        let bill = makeBill(name: "Rent", dueDate: makeDate(year: 2025, month: 1, day: 10, calendar: calendar), in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: bill.dueDate)

        let sut = CalendarListItem.bill(BillDisplay(occurrence: occurrence, status: .upcoming))

        #expect(sut.date == bill.dueDate)
    }

    @Test
    func when_paymentItem_then_dateReturnsDatePaid() throws {
        let calendar = Calendar(identifier: .gregorian)
        let context = try makeContext()
        let dueDate = makeDate(year: 2025, month: 1, day: 15, calendar: calendar)
        let paidDate = makeDate(year: 2025, month: 1, day: 12, calendar: calendar)
        let bill = makeBill(name: "Internet", dueDate: dueDate, in: context)
        let payment = makePayment(amount: 45, paid: paidDate, occurrence: dueDate, bill: bill, in: context)

        let sut = CalendarListItem.payment(payment)

        #expect(sut.date == paidDate)
    }

    @Test
    func when_emptyMonthWithDifferentSectionIds_then_idsAreUnique() {
        let first = CalendarListItem.emptyMonth(sectionId: "2025-01")
        let second = CalendarListItem.emptyMonth(sectionId: "2025-02")

        #expect(first.id != second.id)
    }

    @Test
    func when_billItem_then_typeSortOrderEquals1() throws {
        let calendar = Calendar(identifier: .gregorian)
        let context = try makeContext()
        let dueDate = makeDate(year: 2025, month: 2, day: 1, calendar: calendar)
        let bill = makeBill(name: "A", dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: dueDate)

        #expect(CalendarListItem.bill(BillDisplay(occurrence: occurrence, status: .missed)).typeSortOrder == 1)
    }

    @Test
    func when_paymentItem_then_typeSortOrderEquals1() throws {
        let calendar = Calendar(identifier: .gregorian)
        let context = try makeContext()
        let dueDate = makeDate(year: 2025, month: 2, day: 10, calendar: calendar)
        let bill = makeBill(name: "A", dueDate: dueDate, in: context)
        let payment = makePayment(amount: 10, paid: dueDate, occurrence: dueDate, bill: bill, in: context)

        #expect(CalendarListItem.payment(payment).typeSortOrder == 1)
    }
}

// MARK: - Helpers

@MainActor
private func makeContext() throws -> ModelContext {
    let schema = Schema([Bill.self, PaymentEntry.self, IssuedOccurrence.self])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    return ModelContext(container)
}

@MainActor
@discardableResult
private func makeBill(name: String, dueDate: Date, amount: Decimal = 50, in context: ModelContext) -> Bill {
    let bill = Bill(name: name, amount: amount, dueDate: dueDate)
    context.insert(bill)
    return bill
}

private func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = day
    return calendar.date(from: comps)!
}

@MainActor
@discardableResult
private func makePayment(amount: Decimal, paid date: Date, occurrence: Date, bill: Bill, in context: ModelContext) -> PaymentEntry {
    makePaymentEntry(
        amount: amount,
        datePaid: date,
        occurrenceDate: occurrence,
        bill: bill,
        in: context
    )
}
