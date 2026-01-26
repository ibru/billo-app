//  Created by Jiri Urbasek on 12/19/25.

import Foundation
import SwiftData
import Testing
@testable import Billo

@MainActor
@Suite("PastBillDisplay")
struct PastBillDisplayTests {
    @Test
    func when_noPayments_then_statusIsMissed() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let dueDate = makeDate(year: 2025, month: 1, day: 15, calendar: calendar)

        let bill = makeBill(name: "Rent", amount: 100, dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: dueDate)

        let sut = PastBillDisplay(occurrence: occurrence, payments: [])

        #expect(sut.status == .missed)
    }

    @Test
    func when_singlePaymentCoversFullAmount_then_statusIsPaid() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let dueDate = makeDate(year: 2025, month: 2, day: 1, calendar: calendar)

        let bill = makeBill(name: "Loan", amount: 100, dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: dueDate)
        let payment = makePayment(amount: 100, paid: dueDate, occurrence: dueDate, bill: bill, in: context)

        let sut = PastBillDisplay(occurrence: occurrence, payments: [payment])

        #expect(sut.status == .paid)
    }

    @Test
    func when_multiplePaymentsCoverFullAmount_then_statusIsPaid() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let dueDate = makeDate(year: 2025, month: 2, day: 10, calendar: calendar)

        let bill = makeBill(name: "Insurance", amount: 100, dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: dueDate)
        let payment1 = makePayment(amount: 50, paid: dueDate, occurrence: dueDate, bill: bill, in: context)
        let payment2 = makePayment(amount: 50, paid: dueDate, occurrence: dueDate, bill: bill, in: context)

        let sut = PastBillDisplay(occurrence: occurrence, payments: [payment1, payment2])

        #expect(sut.status == .paid)
    }

    @Test
    func when_paymentsExceedAmount_then_statusIsPaid() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let dueDate = makeDate(year: 2025, month: 3, day: 1, calendar: calendar)

        let bill = makeBill(name: "Overpaid", amount: 100, dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: dueDate)
        let payment1 = makePayment(amount: 80, paid: dueDate, occurrence: dueDate, bill: bill, in: context)
        let payment2 = makePayment(amount: 40, paid: dueDate, occurrence: dueDate, bill: bill, in: context)

        let sut = PastBillDisplay(occurrence: occurrence, payments: [payment1, payment2])

        #expect(sut.status == .paid)
    }

    @Test
    func when_partialPayment_then_statusIsPartiallyPaidWithCorrectAmounts() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let dueDate = makeDate(year: 2025, month: 4, day: 1, calendar: calendar)

        let bill = makeBill(name: "Partial", amount: 100, dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: dueDate)
        let payment = makePayment(amount: 30, paid: dueDate, occurrence: dueDate, bill: bill, in: context)

        let sut = PastBillDisplay(occurrence: occurrence, payments: [payment])

        #expect(sut.status == .partiallyPaid(paid: 30, remaining: 70))
    }

    @Test
    func when_multiplePartialPayments_then_remainingIsCorrect() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let dueDate = makeDate(year: 2025, month: 4, day: 10, calendar: calendar)

        let bill = makeBill(name: "Partial", amount: 100, dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: dueDate)
        let payment1 = makePayment(amount: 50, paid: dueDate, occurrence: dueDate, bill: bill, in: context)
        let payment2 = makePayment(amount: 10, paid: dueDate, occurrence: dueDate, bill: bill, in: context)

        let sut = PastBillDisplay(occurrence: occurrence, payments: [payment1, payment2])

        #expect(sut.status == .partiallyPaid(paid: 60, remaining: 40))
    }

    @Test
    func when_fullyPaid_then_lastPaymentDateReturnsLatest() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let dueDate = makeDate(year: 2025, month: 5, day: 20, calendar: calendar)

        let bill = makeBill(name: "Paid", amount: 100, dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: dueDate)
        let earlierPaymentDate = makeDate(year: 2025, month: 5, day: 1, calendar: calendar)
        let latestPaymentDate = makeDate(year: 2025, month: 5, day: 10, calendar: calendar)
        let payment1 = makePayment(amount: 60, paid: earlierPaymentDate, occurrence: dueDate, bill: bill, in: context)
        let payment2 = makePayment(amount: 40, paid: latestPaymentDate, occurrence: dueDate, bill: bill, in: context)

        let sut = PastBillDisplay(occurrence: occurrence, payments: [payment1, payment2])

        #expect(sut.lastPaymentDate == latestPaymentDate)
    }

    @Test
    func when_paymentsSortedByDate_then_orderedAscending() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let dueDate = makeDate(year: 2025, month: 6, day: 10, calendar: calendar)

        let bill = makeBill(name: "Sorting", amount: 100, dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: dueDate)
        let day1 = makeDate(year: 2025, month: 6, day: 1, calendar: calendar)
        let day2 = makeDate(year: 2025, month: 6, day: 5, calendar: calendar)
        let payment1 = makePayment(amount: 10, paid: day2, occurrence: dueDate, bill: bill, in: context)
        let payment2 = makePayment(amount: 10, paid: day1, occurrence: dueDate, bill: bill, in: context)

        let sut = PastBillDisplay(occurrence: occurrence, payments: [payment1, payment2])

        #expect(sut.paymentsSortedByDate.map(\.datePaid) == [day1, day2])
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
private func makeBill(name: String, amount: Decimal, dueDate: Date, in context: ModelContext) -> Bill {
    let bill = Bill(name: name, amount: amount, dueDate: dueDate)
    context.insert(bill)
    return bill
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

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
}

private func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
}
