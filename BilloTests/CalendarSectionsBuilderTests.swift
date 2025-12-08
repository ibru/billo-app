//  Created by Jiri Urbasek on 12/05/25.

import Testing
import SwiftData
import Foundation
@testable import Billo

@MainActor
@Suite("CalendarSectionsBuilder")
struct CalendarSectionsBuilderTests {
    @Test
    func when_buildingWithOccurrencesAndPayments_then_interleavesSortedByDate() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let start = DateComponents(year: 2025, month: 1)
        let end = DateComponents(year: 2025, month: 2)

        let billA = makeBill(name: "Rent", dueDate: makeDate(year: 2025, month: 1, day: 10, calendar: calendar), in: context)
        let billB = makeBill(name: "Insurance", dueDate: makeDate(year: 2025, month: 2, day: 5, calendar: calendar), in: context)

        let occurrences = [
            BillOccurrence(bill: billA, dueDate: billA.dueDate),
            BillOccurrence(bill: billB, dueDate: billB.dueDate)
        ]
        let payments = [
            makePayment(amount: 50, paid: makeDate(year: 2025, month: 1, day: 15, calendar: calendar), occurrence: billA.dueDate, bill: billA, in: context),
            makePayment(amount: 80, paid: makeDate(year: 2025, month: 2, day: 1, calendar: calendar), occurrence: billB.dueDate, bill: billB, in: context)
        ]

        let sections = CalendarSectionsBuilder.build(
            occurrences: occurrences,
            payments: payments,
            from: start,
            to: end,
            calendar: calendar
        )

        let january = try #require(sections.first { $0.id == "2025-01" })
        let february = try #require(sections.first { $0.id == "2025-02" })

        let januaryDates = january.items.map(\.date)
        let februaryDates = february.items.map(\.date)

        #expect(januaryDates.count == 2)
        #expect(januaryDates.sorted() == [
            makeDate(year: 2025, month: 1, day: 10, calendar: calendar),
            makeDate(year: 2025, month: 1, day: 15, calendar: calendar)
        ])
        #expect(februaryDates.count == 2)
        #expect(februaryDates.sorted() == [
            makeDate(year: 2025, month: 2, day: 1, calendar: calendar),
            makeDate(year: 2025, month: 2, day: 5, calendar: calendar)
        ])
    }

    @Test
    func when_buildingWithEmptyMonth_then_insertsEmptyMonthPlaceholderWithUniqueSectionId() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let start = DateComponents(year: 2025, month: 1)
        let end = DateComponents(year: 2025, month: 3)

        let bill = makeBill(name: "OneTime", dueDate: makeDate(year: 2025, month: 1, day: 2, calendar: calendar), in: context)
        let occurrences = [BillOccurrence(bill: bill, dueDate: bill.dueDate)]

        let sections = CalendarSectionsBuilder.build(
            occurrences: occurrences,
            payments: [],
            from: start,
            to: end,
            calendar: calendar
        )

        let february = sections.first { $0.id == "2025-02" }
        let march = sections.first { $0.id == "2025-03" }

        #expect(february?.items.count == 1)
        #expect(march?.items.count == 1)
        #expect(february?.items.first?.id != march?.items.first?.id)
    }

    @Test
    func when_buildingAcrossYearBoundary_then_createsCorrectMonthSections() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let start = DateComponents(year: 2024, month: 12)
        let end = DateComponents(year: 2025, month: 1)

        let decemberBill = makeBill(name: "Dec", dueDate: makeDate(year: 2024, month: 12, day: 15, calendar: calendar), in: context)
        let januaryBill = makeBill(name: "Jan", dueDate: makeDate(year: 2025, month: 1, day: 20, calendar: calendar), in: context)
        let occurrences = [
            BillOccurrence(bill: decemberBill, dueDate: decemberBill.dueDate),
            BillOccurrence(bill: januaryBill, dueDate: januaryBill.dueDate)
        ]

        let sections = CalendarSectionsBuilder.build(
            occurrences: occurrences,
            payments: [],
            from: start,
            to: end,
            calendar: calendar
        )

        #expect(sections.count == 2)
        #expect(sections.map(\.id) == ["2024-12", "2025-01"])
    }

    @Test
    func when_occurrenceAndPaymentOnSameDay_then_bothAppearInSectionSortedByDate() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let start = DateComponents(year: 2025, month: 4)
        let end = DateComponents(year: 2025, month: 4)

        let bill = makeBill(name: "Utility", dueDate: makeDate(year: 2025, month: 4, day: 10, calendar: calendar), in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: bill.dueDate)
        let payment = makePayment(
            amount: 40,
            paid: makeDate(year: 2025, month: 4, day: 10, calendar: calendar),
            occurrence: bill.dueDate,
            bill: bill,
            in: context
        )

        let sections = CalendarSectionsBuilder.build(
            occurrences: [occurrence],
            payments: [payment],
            from: start,
            to: end,
            calendar: calendar
        )

        let april = try #require(sections.first)
        #expect(april.items.count == 2)
        #expect(april.items.first?.date == bill.dueDate)
    }

    @Test
    func when_multipleEmptyMonths_then_eachHasUniqueId() {
        let calendar = utcCalendar()
        let start = DateComponents(year: 2025, month: 5)
        let end = DateComponents(year: 2025, month: 7)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [],
            payments: [],
            from: start,
            to: end,
            calendar: calendar
        )

        let ids = sections.flatMap { section in section.items.map(\.id) }
        #expect(Set(ids).count == ids.count)
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
private func makeBill(name: String, dueDate: Date, in context: ModelContext) -> Bill {
    let bill = Bill(name: name, amount: 50, dueDate: dueDate)
    context.insert(bill)
    return bill
}

@MainActor
@discardableResult
private func makePayment(
    amount: Decimal,
    paid: Date,
    occurrence: Date,
    bill: Bill,
    in context: ModelContext
) -> Payment {
    let payment = Payment(
        amount: amount,
        datePaid: paid,
        occurrenceDate: occurrence,
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
