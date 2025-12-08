//  Created by Jiri Urbasek on 12/05/25.

import Testing
import SwiftData
import Foundation
@testable import Billo

@MainActor
@Suite("DotIndicator - Colors")
struct DotIndicatorTests {
    @Test
    func when_dueDateIsOverdue_then_colorIsRed() {
        let calendar = utcCalendar()
        let today = makeDate(year: 2025, month: 1, day: 10, calendar: calendar)
        let dueDate = makeDate(year: 2025, month: 1, day: 5, calendar: calendar)

        let color = DotIndicatorGenerator.urgencyColor(
            for: dueDate,
            relativeTo: today,
            calendar: calendar
        )

        #expect(color == .red)
    }

    @Test
    func when_dueDateIsToday_then_colorIsRed() {
        let calendar = utcCalendar()
        let today = makeDate(year: 2025, month: 1, day: 10, calendar: calendar)

        let color = DotIndicatorGenerator.urgencyColor(
            for: today,
            relativeTo: today,
            calendar: calendar
        )

        #expect(color == .red)
    }

    @Test
    func when_dueDateIs1DayAway_then_colorIsOrange() {
        let calendar = utcCalendar()
        let today = makeDate(year: 2025, month: 1, day: 10, calendar: calendar)
        let dueDate = makeDate(year: 2025, month: 1, day: 11, calendar: calendar)

        let color = DotIndicatorGenerator.urgencyColor(
            for: dueDate,
            relativeTo: today,
            calendar: calendar
        )

        #expect(color == .orange)
    }

    @Test
    func when_dueDateIs7DaysAway_then_colorIsOrange() {
        let calendar = utcCalendar()
        let today = makeDate(year: 2025, month: 1, day: 10, calendar: calendar)
        let dueDate = makeDate(year: 2025, month: 1, day: 17, calendar: calendar)

        let color = DotIndicatorGenerator.urgencyColor(
            for: dueDate,
            relativeTo: today,
            calendar: calendar
        )

        #expect(color == .orange)
    }

    @Test
    func when_dueDateIs8DaysAway_then_colorIsYellow() {
        let calendar = utcCalendar()
        let today = makeDate(year: 2025, month: 1, day: 10, calendar: calendar)
        let dueDate = makeDate(year: 2025, month: 1, day: 18, calendar: calendar)

        let color = DotIndicatorGenerator.urgencyColor(
            for: dueDate,
            relativeTo: today,
            calendar: calendar
        )

        #expect(color == .yellow)
    }

    @Test
    func when_dueDateIs30DaysAway_then_colorIsYellow() {
        let calendar = utcCalendar()
        let today = makeDate(year: 2025, month: 1, day: 10, calendar: calendar)
        let dueDate = makeDate(year: 2025, month: 2, day: 9, calendar: calendar)

        let color = DotIndicatorGenerator.urgencyColor(
            for: dueDate,
            relativeTo: today,
            calendar: calendar
        )

        #expect(color == .yellow)
    }

    @Test
    func when_dueDateIs31DaysAway_then_colorIsGray() {
        let calendar = utcCalendar()
        let today = makeDate(year: 2025, month: 1, day: 10, calendar: calendar)
        let dueDate = makeDate(year: 2025, month: 2, day: 10, calendar: calendar)

        let color = DotIndicatorGenerator.urgencyColor(
            for: dueDate,
            relativeTo: today,
            calendar: calendar
        )

        #expect(color == .gray)
    }

    @Test @MainActor
    func when_itemIsPayment_then_colorIsGreen() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let bill = makeBill(name: "Loan", amount: 100, dueDate: makeDate(year: 2025, month: 3, day: 1, calendar: calendar), in: context)
        let payment = Payment(
            amount: 100,
            datePaid: bill.dueDate,
            occurrenceDate: bill.dueDate,
            bill: bill
        )
        context.insert(payment)
        let dayData = CalendarDayData(date: bill.dueDate, occurrences: [], payments: [payment])

        let dots = DotIndicatorGenerator.dots(
            for: dayData,
            relativeTo: bill.dueDate,
            calendar: calendar
        )

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
