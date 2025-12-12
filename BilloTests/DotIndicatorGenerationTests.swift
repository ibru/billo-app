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

    @Test
    func when_dayHasIncome_then_includesIncomeDot() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let date = makeDate(year: 2025, month: 11, day: 1, calendar: calendar)

        let income = makeIncome(name: "Salary", amount: 3000, startDate: date, in: context)
        let incomeOccurrence = IncomeOccurrence(from: income, on: date)

        let dayData = CalendarDayData(date: date, occurrences: [], payments: [], incomeOccurrences: [incomeOccurrence])

        let dots = DotIndicatorGenerator.dots(for: dayData, relativeTo: date, calendar: calendar)

        #expect(dots.count == 1)
        #expect(dots.first?.color == .income)
    }

    @Test
    func when_dayHasMultipleIncomes_then_includesMultipleIncomeDots() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let date = makeDate(year: 2025, month: 11, day: 15, calendar: calendar)

        let income1 = makeIncome(name: "Salary", amount: 3000, startDate: date, in: context)
        let income2 = makeIncome(name: "Freelance", amount: 500, startDate: date, in: context)
        let incomeOccurrences = [
            IncomeOccurrence(from: income1, on: date),
            IncomeOccurrence(from: income2, on: date)
        ]

        let dayData = CalendarDayData(date: date, occurrences: [], payments: [], incomeOccurrences: incomeOccurrences)

        let dots = DotIndicatorGenerator.dots(for: dayData, relativeTo: date, calendar: calendar)

        #expect(dots.count == 2)
        #expect(dots.allSatisfy { $0.color == .income })
    }

    @Test
    func when_dayHasBillsAndIncome_then_includesBothDotTypes() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let date = makeDate(year: 2025, month: 12, day: 1, calendar: calendar)

        let bill = makeBill(name: "Rent", amount: 1500, dueDate: date, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: date)

        let income = makeIncome(name: "Salary", amount: 4000, startDate: date, in: context)
        let incomeOccurrence = IncomeOccurrence(from: income, on: date)

        let dayData = CalendarDayData(
            date: date,
            occurrences: [occurrence],
            payments: [],
            incomeOccurrences: [incomeOccurrence]
        )

        // Bill is 1 day in future relative to yesterday -> orange
        let dots = DotIndicatorGenerator.dots(for: dayData, relativeTo: date.addingTimeInterval(-86400), calendar: calendar)

        #expect(dots.count == 2)
        #expect(dots.contains { $0.color == .income })
        #expect(dots.contains { $0.color == .orange }) // Bill due tomorrow relative to yesterday
    }

    @Test
    func when_dayHasBillsPaymentsAndIncome_then_includesAllDotTypes() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let date = makeDate(year: 2025, month: 12, day: 15, calendar: calendar)

        // Unpaid bill
        let unpaidBill = makeBill(name: "Internet", amount: 50, dueDate: date, in: context)
        let unpaidOccurrence = BillOccurrence(bill: unpaidBill, dueDate: date)

        // Paid bill with payment
        let paidBill = makeBill(name: "Phone", amount: 30, dueDate: date, in: context)
        let paidOccurrence = BillOccurrence(bill: paidBill, dueDate: date)
        let payment = Payment(amount: 30, datePaid: date, occurrenceDate: date, bill: paidBill)
        context.insert(payment)

        // Income
        let income = makeIncome(name: "Bonus", amount: 500, startDate: date, in: context)
        let incomeOccurrence = IncomeOccurrence(from: income, on: date)

        let dayData = CalendarDayData(
            date: date,
            occurrences: [unpaidOccurrence, paidOccurrence],
            payments: [payment],
            incomeOccurrences: [incomeOccurrence]
        )

        // Bill is 1 day in future relative to yesterday -> orange
        let dots = DotIndicatorGenerator.dots(for: dayData, relativeTo: date.addingTimeInterval(-86400), calendar: calendar)

        // Should have: 1 income dot, 1 unpaid bill dot (paid occurrence filtered out), 1 payment dot
        #expect(dots.count == 3)
        #expect(dots.filter { $0.color == .income }.count == 1)
        #expect(dots.filter { $0.color == .green }.count == 1) // Payment
        #expect(dots.filter { $0.color == .orange }.count == 1) // Unpaid bill due tomorrow
    }
}

// MARK: - Helpers

@MainActor
private func makeContext() throws -> ModelContext {
    let schema = Schema([Bill.self, Payment.self, Income.self, RecurrenceRule.self])
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
private func makeIncome(name: String, amount: Decimal, startDate: Date, in context: ModelContext) -> Income {
    let income = Income(name: name, amount: amount, startDate: startDate)
    context.insert(income)
    return income
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
