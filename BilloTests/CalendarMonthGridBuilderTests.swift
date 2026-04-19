//  Created by Jiri Urbasek on 12/05/25.

import Foundation
import SwiftData
import Testing
@testable import Billo

@MainActor
@Suite("CalendarMonthGridBuilder")
struct CalendarMonthGridBuilderTests {
    @Test
    func when_unpaidOccurrenceInMonth_then_dayDataContainsBill() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let month = DateComponents(year: 2025, month: 1)
        let referenceDate = makeDate(year: 2024, month: 12, day: 31, calendar: calendar)

        let bill = makeBill(name: "Rent", dueDate: makeDate(year: 2025, month: 1, day: 5, calendar: calendar), in: context)
        let occurrences = [BillOccurrence(bill: bill, dueDate: bill.dueDate)]

        let grid = CalendarMonthGridBuilder.build(
            month: month,
            calendar: calendar,
            occurrences: occurrences,
            payments: [],
            referenceDate: referenceDate
        )

        let dayKey = calendar.startOfDay(for: bill.dueDate)
        let dayData = try #require(grid[dayKey])
        #expect(dayData.bills.count == 1)
        #expect(dayData.bills.first?.status == .upcoming)
        #expect(dayData.payments.isEmpty)
    }

    @Test
    func when_paymentInMonth_then_dayDataContainsPayment() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let month = DateComponents(year: 2025, month: 2)
        let referenceDate = makeDate(year: 2025, month: 2, day: 1, calendar: calendar)

        let bill = makeBill(name: "Loan", dueDate: makeDate(year: 2025, month: 1, day: 20, calendar: calendar), in: context)
        let paymentDate = makeDate(year: 2025, month: 2, day: 2, calendar: calendar)
        let payment = makePayment(amount: 100, paid: paymentDate, occurrence: bill.dueDate, bill: bill, in: context)

        let grid = CalendarMonthGridBuilder.build(
            month: month,
            calendar: calendar,
            occurrences: [],
            payments: [payment],
            referenceDate: referenceDate
        )

        let dayKey = calendar.startOfDay(for: paymentDate)
        let dayData = try #require(grid[dayKey])
        #expect(dayData.payments.count == 1)
        #expect(dayData.bills.isEmpty)
    }

    @Test
    func when_fullyPaidOccurrence_then_billSkippedButPaymentShows() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let month = DateComponents(year: 2025, month: 3)
        let referenceDate = makeDate(year: 2025, month: 3, day: 9, calendar: calendar)

        let dueDate = makeDate(year: 2025, month: 3, day: 10, calendar: calendar)
        let bill = makeBill(name: "Utilities", amount: 60, dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: dueDate)
        let payment = makePayment(amount: 60, paid: dueDate, occurrence: dueDate, bill: bill, in: context)

        let grid = CalendarMonthGridBuilder.build(
            month: month,
            calendar: calendar,
            occurrences: [occurrence],
            payments: [payment],
            referenceDate: referenceDate
        )

        let dayKey = calendar.startOfDay(for: dueDate)
        let dayData = try #require(grid[dayKey])
        #expect(dayData.bills.isEmpty, "Fully paid bill should not appear in bills")
        #expect(dayData.payments.count == 1, "Payment should still appear")
    }

    @Test
    func when_partiallyPaidOccurrence_then_billShowsAsPartiallyPaid() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let month = DateComponents(year: 2025, month: 3)
        let referenceDate = makeDate(year: 2025, month: 3, day: 9, calendar: calendar)

        let dueDate = makeDate(year: 2025, month: 3, day: 10, calendar: calendar)
        let bill = makeBill(name: "Utilities", amount: 100, dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: dueDate)
        let payment = makePayment(amount: 40, paid: dueDate, occurrence: dueDate, bill: bill, in: context)

        let grid = CalendarMonthGridBuilder.build(
            month: month,
            calendar: calendar,
            occurrences: [occurrence],
            payments: [payment],
            referenceDate: referenceDate
        )

        let dayKey = calendar.startOfDay(for: dueDate)
        let dayData = try #require(grid[dayKey])
        #expect(dayData.bills.count == 1)
        #expect(dayData.bills.first?.status == .partiallyPaid(paid: 40, remaining: 60))
        #expect(dayData.payments.count == 1)
    }

    @Test
    func when_unpaidPastOccurrence_then_billShowsAsMissed() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let month = DateComponents(year: 2025, month: 4)
        let referenceDate = makeDate(year: 2025, month: 4, day: 20, calendar: calendar)

        let dueDate = makeDate(year: 2025, month: 4, day: 5, calendar: calendar)
        let bill = makeBill(name: "Missed", dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: dueDate)

        let grid = CalendarMonthGridBuilder.build(
            month: month,
            calendar: calendar,
            occurrences: [occurrence],
            payments: [],
            referenceDate: referenceDate
        )

        let dayKey = calendar.startOfDay(for: dueDate)
        let dayData = try #require(grid[dayKey])
        #expect(dayData.bills.count == 1)
        #expect(dayData.bills.first?.status == .missed)
    }

    @Test
    func when_multipleOccurrencesSameDay_then_allRetained() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let month = DateComponents(year: 2025, month: 4)
        let referenceDate = makeDate(year: 2025, month: 4, day: 1, calendar: calendar)

        let day = makeDate(year: 2025, month: 4, day: 15, calendar: calendar)
        let billA = makeBill(name: "A", dueDate: day, in: context)
        let billB = makeBill(name: "B", dueDate: day, in: context)
        let occurrences = [
            BillOccurrence(bill: billA, dueDate: day),
            BillOccurrence(bill: billB, dueDate: day)
        ]

        let grid = CalendarMonthGridBuilder.build(
            month: month,
            calendar: calendar,
            occurrences: occurrences,
            payments: [],
            referenceDate: referenceDate
        )

        let dayKey = calendar.startOfDay(for: day)
        let dayData = try #require(grid[dayKey])
        #expect(dayData.bills.count == 2)
    }

    @Test
    func when_itemsOutsideMonth_then_ignored() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let month = DateComponents(year: 2025, month: 5)
        let referenceDate = makeDate(year: 2025, month: 5, day: 1, calendar: calendar)

        let inMonthDate = makeDate(year: 2025, month: 5, day: 1, calendar: calendar)
        let outMonthDate = makeDate(year: 2025, month: 6, day: 1, calendar: calendar)

        let billIn = makeBill(name: "In", dueDate: inMonthDate, in: context)
        let billOut = makeBill(name: "Out", dueDate: outMonthDate, in: context)

        let occurrences = [
            BillOccurrence(bill: billIn, dueDate: inMonthDate),
            BillOccurrence(bill: billOut, dueDate: outMonthDate)
        ]

        let payment = makePayment(amount: 10, paid: outMonthDate, occurrence: billOut.dueDate, bill: billOut, in: context)

        let grid = CalendarMonthGridBuilder.build(
            month: month,
            calendar: calendar,
            occurrences: occurrences,
            payments: [payment],
            referenceDate: referenceDate
        )

        #expect(grid.keys.count == 1)
        let key = calendar.startOfDay(for: inMonthDate)
        #expect(grid[key]?.bills.count == 1)
        #expect(grid[key]?.payments.count == 0)
    }

    @Test
    func when_invalidMonthComponents_then_returnsEmpty() {
        let calendar = utcCalendar()
        let grid = CalendarMonthGridBuilder.build(
            month: DateComponents(), // missing month/year
            calendar: calendar,
            occurrences: [],
            payments: [],
            referenceDate: Date()
        )

        #expect(grid.isEmpty)
    }

    @Test
    func when_paymentIsOrphanedBecauseBillWasDeleted_then_paymentStillAppearsInDayData() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let month = DateComponents(year: 2025, month: 7)
        let referenceDate = makeDate(year: 2025, month: 7, day: 28, calendar: calendar)

        let orphanDate = makeDate(year: 2025, month: 7, day: 15, calendar: calendar)
        let orphanPayment = try makeOrphanPaymentEntry(
            amount: 25,
            datePaid: orphanDate,
            occurrenceDate: orphanDate,
            billName: "Deleted",
            calendar: calendar,
            in: context
        )

        let grid = CalendarMonthGridBuilder.build(
            month: month,
            calendar: calendar,
            occurrences: [],
            payments: [orphanPayment],
            referenceDate: referenceDate
        )

        let dayKey = calendar.startOfDay(for: orphanDate)
        let dayData = try #require(grid[dayKey])
        #expect(dayData.payments.count == 1)
        #expect(dayData.payments.first === orphanPayment)
    }

    @Test
    func when_paymentDateIsInMonthButOccurrenceDueDateIsInDifferentMonth_then_paymentAppearsInThatMonthDayData() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let january = DateComponents(year: 2025, month: 1)
        let referenceDate = makeDate(year: 2025, month: 1, day: 15, calendar: calendar)

        let dueDateInFebruary = makeDate(year: 2025, month: 2, day: 15, calendar: calendar)
        let bill = makeBill(name: "Prepaid", dueDate: dueDateInFebruary, in: context)

        let paymentDateInJanuary = makeDate(year: 2025, month: 1, day: 10, calendar: calendar)
        let payment = makePayment(amount: 100, paid: paymentDateInJanuary, occurrence: dueDateInFebruary, bill: bill, in: context)

        let grid = CalendarMonthGridBuilder.build(
            month: january,
            calendar: calendar,
            occurrences: [], // due date is in February
            payments: [payment],
            referenceDate: referenceDate
        )

        let dayKey = calendar.startOfDay(for: paymentDateInJanuary)
        let dayData = try #require(grid[dayKey])
        #expect(dayData.payments.count == 1)
    }
}

// MARK: - Helpers

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
}

private func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
}

private func makeContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Bill.self, PaymentEntry.self, IssuedOccurrence.self, configurations: config)
    return ModelContext(container)
}

@discardableResult
private func makeBill(name: String, dueDate: Date, in context: ModelContext) -> Bill {
    let bill = Bill(
        name: name,
        amount: Decimal(100),
        currencyCode: "USD",
        dueDate: dueDate,
        notes: nil,
        accountIdentifier: nil,
        providerURL: nil,
        categoryIdentifier: .predefined(.utilities),
        recurrenceRule: nil
    )
    context.insert(bill)
    return bill
}

@discardableResult
private func makeBill(name: String, amount: Decimal, dueDate: Date, in context: ModelContext) -> Bill {
    let bill = Bill(
        name: name,
        amount: amount,
        currencyCode: "USD",
        dueDate: dueDate,
        notes: nil,
        accountIdentifier: nil,
        providerURL: nil,
        categoryIdentifier: .predefined(.utilities),
        recurrenceRule: nil
    )
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
