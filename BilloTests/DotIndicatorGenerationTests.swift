//  Created by Jiri Urbasek on 12/05/25.

import Testing
import SwiftData
import Foundation
@testable import Billo

@MainActor
@Suite("DotIndicator - Generation")
struct DotIndicatorGenerationTests {
    @Test
    func when_dayHasMultipleOccurrences_then_eachGetsOwnDot() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let date = makeDate(year: 2025, month: 7, day: 10, calendar: calendar)
        let bills = [
            makeBill(name: "A", amount: 10, dueDate: date, in: context),
            makeBill(name: "B", amount: 15, dueDate: date, in: context)
        ]

        let occurrences = bills.map { BillOccurrence(bill: $0, dueDate: $0.dueDate) }
        let dayData = CalendarDayData(date: date, occurrences: occurrences, payments: [])

        let dots = DotIndicatorGenerator.dots(for: dayData, relativeTo: date, calendar: calendar)

        #expect(dots.count == 2)
    }

    @Test
    func when_dayHasOccurrenceAndPayment_then_bothDotsGenerated() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let date = makeDate(year: 2025, month: 8, day: 1, calendar: calendar)
        let bill = makeBill(name: "Phone", amount: 30, dueDate: date, in: context)

        let occurrence = BillOccurrence(bill: bill, dueDate: bill.dueDate)
        let payment = Payment(amount: 10, datePaid: date, occurrenceDate: date, bill: bill)
        context.insert(payment)

        let dayData = CalendarDayData(date: date, occurrences: [occurrence], payments: [payment])

        let dots = DotIndicatorGenerator.dots(for: dayData, relativeTo: date.addingTimeInterval(-86400), calendar: calendar)

        #expect(dots.count == 2)
    }

    @Test
    func when_dayHasMoreThanFourItems_then_overflowCanBeCalculated() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let date = makeDate(year: 2025, month: 9, day: 12, calendar: calendar)
        let bills = (0..<5).map { index in
            makeBill(name: "Bill \(index)", amount: 10, dueDate: date, in: context)
        }

        let occurrences = bills.map { BillOccurrence(bill: $0, dueDate: $0.dueDate) }
        let dayData = CalendarDayData(date: date, occurrences: occurrences, payments: [])

        let dots = DotIndicatorGenerator.dots(for: dayData, relativeTo: date.addingTimeInterval(-86400), calendar: calendar)

        #expect(dots.count == 5)
    }

    @Test
    func when_occurrenceMarkedPaid_then_occurrenceDotRemovedPaymentDotAdded() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let date = makeDate(year: 2025, month: 10, day: 5, calendar: calendar)

        let bill = makeBill(name: "Loan", amount: 100, dueDate: date, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: bill.dueDate)
        let payment = Payment(amount: 100, datePaid: date, occurrenceDate: date, bill: bill)
        context.insert(payment)

        let dayData = CalendarDayData(date: date, occurrences: [occurrence], payments: [payment])

        let dots = DotIndicatorGenerator.dots(for: dayData, relativeTo: date, calendar: calendar)

        #expect(dots.count == 1)
        #expect(dots.first?.color == .green)
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
