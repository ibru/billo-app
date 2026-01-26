//  Created by Jiri Urbasek on 12/05/25.

import Testing
import SwiftData
import Foundation
@testable import Billo

@MainActor
@Suite("CalendarNavigationBounds")
struct CalendarNavigationBoundsTests {
    @Test
    func when_billsExistBeforePayments_then_earliestMonthFromBills() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let earlyDate = makeDate(year: 2024, month: 12, day: 15, calendar: calendar)
        let laterPaymentDate = makeDate(year: 2025, month: 2, day: 10, calendar: calendar)

        let earlyBill = Bill(name: "Early", amount: 10, dueDate: earlyDate)
        let laterBill = Bill(name: "Later", amount: 10, dueDate: makeDate(year: 2025, month: 3, day: 1, calendar: calendar))
        context.insert(earlyBill)
        context.insert(laterBill)

        let payment = makePaymentEntry(
            amount: 10,
            datePaid: laterPaymentDate,
            occurrenceDate: laterPaymentDate,
            bill: laterBill,
            calendar: calendar,
            in: context
        )

        let components = CalendarNavigationBounds.earliestMonth(
            bills: [earlyBill, laterBill],
            payments: [payment],
            calendar: calendar,
            currentDate: makeDate(year: 2025, month: 1, day: 1, calendar: calendar)
        )

        #expect(components.year == 2024)
        #expect(components.month == 12)
    }

    @Test
    func when_paymentsExistBeforeBills_then_earliestMonthFromPayments() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let paymentDate = makeDate(year: 2024, month: 11, day: 20, calendar: calendar)

        let bill = Bill(name: "Rent", amount: 50, dueDate: makeDate(year: 2025, month: 2, day: 1, calendar: calendar))
        context.insert(bill)

        let payment = makePaymentEntry(
            amount: 50,
            datePaid: paymentDate,
            occurrenceDate: paymentDate,
            bill: bill,
            calendar: calendar,
            in: context
        )

        let components = CalendarNavigationBounds.earliestMonth(
            bills: [bill],
            payments: [payment],
            calendar: calendar,
            currentDate: makeDate(year: 2025, month: 1, day: 15, calendar: calendar)
        )

        #expect(components.year == 2024)
        #expect(components.month == 11)
    }

    @Test
    func when_noBillsOrPayments_then_earliestMonthIsCurrentMonth() {
        let calendar = utcCalendar()
        let now = makeDate(year: 2025, month: 3, day: 5, calendar: calendar)

        let components = CalendarNavigationBounds.earliestMonth(
            bills: [],
            payments: [],
            calendar: calendar,
            currentDate: now
        )

        #expect(components.year == 2025)
        #expect(components.month == 3)
    }

    @Test
    func when_calculatingLatestMonth_then_addsConfiguredFutureLimit() {
        let calendar = utcCalendar()
        let referenceDate = makeDate(year: 2025, month: 1, day: 15, calendar: calendar)

        let components = CalendarNavigationBounds.latestMonth(
            from: referenceDate,
            calendar: calendar
        )

        #expect(components.year == 2028)
        #expect(components.month == 1)
    }

    @Test
    func when_futureMonthLimitChanged_then_latestMonthReflectsNewLimit() {
        let calendar = utcCalendar()
        let referenceDate = makeDate(year: 2025, month: 6, day: 1, calendar: calendar)

        let components = CalendarNavigationBounds.latestMonth(
            from: referenceDate,
            calendar: calendar,
            limit: 6
        )

        #expect(components.year == 2025)
        #expect(components.month == 12)
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
