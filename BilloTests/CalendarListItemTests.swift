//  Created by Jiri Urbasek on 12/05/25.

import Testing
import SwiftData
import Foundation
@testable import Billo

@MainActor
@Suite("CalendarListItem")
struct CalendarListItemTests {
    @Test
    func when_occurrenceItem_then_dateReturnsDueDate() throws {
        let calendar = Calendar(identifier: .gregorian)
        let context = try makeContext()
        let bill = makeBill(name: "Rent", dueDate: makeDate(year: 2025, month: 1, day: 10, calendar: calendar), in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: bill.dueDate)

        let sut = CalendarListItem.occurrence(occurrence)

        #expect(sut.date == bill.dueDate)
    }

    @Test
    func when_paymentItem_then_dateReturnsDatePaid() throws {
        let calendar = Calendar(identifier: .gregorian)
        let context = try makeContext()
        let bill = makeBill(name: "Internet", dueDate: makeDate(year: 2025, month: 1, day: 15, calendar: calendar), in: context)
        let paymentDate = makeDate(year: 2025, month: 1, day: 12, calendar: calendar)
        let payment = Payment(
            amount: 45,
            datePaid: paymentDate,
            occurrenceDate: bill.dueDate,
            bill: bill
        )
        context.insert(payment)

        let sut = CalendarListItem.payment(payment)

        #expect(sut.date == paymentDate)
    }

    @Test
    func when_emptyMonthWithDifferentSectionIds_then_idsAreUnique() {
        let first = CalendarListItem.emptyMonth(sectionId: "2025-01")
        let second = CalendarListItem.emptyMonth(sectionId: "2025-02")

        #expect(first.id != second.id)
    }
}

// MARK: - Helpers

@MainActor
private func makeContext() throws -> ModelContext {
    let schema = Schema([Bill.self, Payment.self])
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
