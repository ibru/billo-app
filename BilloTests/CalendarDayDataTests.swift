//  Created by Jiri Urbasek on 12/05/25.

import Testing
import SwiftData
import Foundation
@testable import Billo

@MainActor
@Suite("CalendarDayData")
struct CalendarDayDataTests {
    @Test
    func when_hasOnlyPastOccurrences_then_hasItemsIsTrue() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let dueDate = makeDate(year: 2025, month: 2, day: 5, calendar: calendar)
        let bill = makeBill(name: "Water", amount: 20, dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: bill.dueDate)
        let payment = makePayment(amount: 20, paid: dueDate, occurrence: dueDate, bill: bill, in: context)

        let sut = CalendarDayData(date: dueDate, pastOccurrences: [PastBillDisplay(occurrence: occurrence, payments: [payment])])

        #expect(sut.hasItems == true)
    }

    @Test
    func when_hasOnlyFutureOccurrences_then_hasItemsIsTrue() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let dueDate = makeDate(year: 2025, month: 3, day: 1, calendar: calendar)
        let bill = makeBill(name: "Future", amount: 10, dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: dueDate)

        let sut = CalendarDayData(
            date: dueDate,
            futureOccurrencesWithPayments: [FutureOccurrenceWithPayments(occurrence: occurrence, payments: [])]
        )

        #expect(sut.hasItems == true)
    }

    @Test
    func when_hasOnlyPayments_then_hasItemsIsTrue() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let dueDate = makeDate(year: 2025, month: 3, day: 5, calendar: calendar)
        let bill = makeBill(name: "Paid", amount: 10, dueDate: dueDate, in: context)
        let payment = makePayment(amount: 10, paid: dueDate, occurrence: dueDate, bill: bill, in: context)

        let sut = CalendarDayData(date: dueDate, payments: [payment])

        #expect(sut.hasItems == true)
    }

    @Test
    func when_allEmpty_then_hasItemsIsFalse() {
        let date = Date()
        let sut = CalendarDayData(date: date)

        #expect(sut.hasItems == false)
    }

    @Test
    func when_totalDueCalculated_then_includesBothFutureAndPastOccurrences() throws {
        let calendar = utcCalendar()
        let context = try makeContext()

        let dueDate = makeDate(year: 2025, month: 6, day: 1, calendar: calendar)
        let billA = makeBill(name: "A", amount: 25, dueDate: dueDate, in: context)
        let billB = makeBill(name: "B", amount: 40, dueDate: dueDate, in: context)

        let future = FutureOccurrenceWithPayments(occurrence: BillOccurrence(bill: billA, dueDate: dueDate), payments: [])
        let past = PastBillDisplay(occurrence: BillOccurrence(bill: billB, dueDate: dueDate), payments: [])

        let sut = CalendarDayData(
            date: dueDate,
            futureOccurrencesWithPayments: [future],
            pastOccurrences: [past]
        )

        #expect(sut.totalDue == 65)
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
private func makeBill(name: String, amount: Decimal, dueDate: Date, in context: ModelContext) -> Bill {
    let bill = Bill(name: name, amount: amount, dueDate: dueDate)
    context.insert(bill)
    return bill
}

@MainActor
@discardableResult
private func makePayment(amount: Decimal, paid date: Date, occurrence: Date, bill: Bill, in context: ModelContext) -> Payment {
    let payment = Payment(
        amount: amount,
        datePaid: date,
        occurrenceDate: occurrence,
        confirmationNumber: nil,
        notes: nil,
        bill: bill
    )
    context.insert(payment)
    return payment
}

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
}

private func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return calendar.date(from: components)!
}
