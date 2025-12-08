//  Created by Jiri Urbasek on 12/05/25.

import Testing
import SwiftData
import Foundation
@testable import Billo

@MainActor
@Suite("CalendarDayData")
struct CalendarDayDataTests {
    @Test
    func when_dayHasOccurrencesAndPayments_then_hasItemsReturnsTrue() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let bill = makeBill(name: "Water", amount: 20, dueDate: makeDate(year: 2025, month: 2, day: 5, calendar: calendar), in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: bill.dueDate)
        let payment = Payment(
            amount: 20,
            datePaid: bill.dueDate,
            occurrenceDate: bill.dueDate,
            bill: bill
        )
        context.insert(payment)

        let sut = CalendarDayData(date: bill.dueDate, occurrences: [occurrence], payments: [payment])

        #expect(sut.hasItems == true)
    }

    @Test
    func when_dayIsEmpty_then_hasItemsReturnsFalse() {
        let date = Date()
        let sut = CalendarDayData(date: date, occurrences: [], payments: [])

        #expect(sut.hasItems == false)
    }

    @Test
    func when_calculatingTotalDue_then_sumsAllOccurrenceAmounts() throws {
        let calendar = utcCalendar()
        let context = try makeContext()

        let billA = makeBill(name: "A", amount: 25, dueDate: makeDate(year: 2025, month: 6, day: 1, calendar: calendar), in: context)
        let billB = makeBill(name: "B", amount: 40, dueDate: makeDate(year: 2025, month: 6, day: 1, calendar: calendar), in: context)

        let occurrences = [
            BillOccurrence(bill: billA, dueDate: billA.dueDate),
            BillOccurrence(bill: billB, dueDate: billB.dueDate)
        ]

        let sut = CalendarDayData(date: billA.dueDate, occurrences: occurrences, payments: [])

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
