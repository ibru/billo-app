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

    // MARK: - Sorting Order Tests

    @Test
    func when_incomePaymentAndOccurrenceOnSameDay_then_sortsIncomeFirstThenPaymentThenOccurrence() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let sameDay = makeDate(year: 2025, month: 3, day: 15, calendar: calendar)
        let start = DateComponents(year: 2025, month: 3)
        let end = DateComponents(year: 2025, month: 3)

        let bill = makeBill(name: "Rent", amount: 1000, dueDate: sameDay, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: sameDay)
        let payment = makePayment(
            amount: 500,
            paid: sameDay,
            occurrence: sameDay,
            bill: bill,
            in: context
        )
        let income = makeIncome(name: "Salary", amount: 3000, startDate: sameDay, in: context)
        let incomeOccurrence = IncomeOccurrence(from: income, on: sameDay)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [occurrence],
            payments: [payment],
            incomeOccurrences: [incomeOccurrence],
            from: start,
            to: end,
            calendar: calendar
        )

        let march = try #require(sections.first { $0.id == "2025-03" })
        #expect(march.items.count == 3)

        // Verify order: income → payment → occurrence
        guard case .income = march.items[0] else {
            Issue.record("Expected first item to be income")
            return
        }
        guard case .payment = march.items[1] else {
            Issue.record("Expected second item to be payment")
            return
        }
        guard case .occurrence = march.items[2] else {
            Issue.record("Expected third item to be occurrence")
            return
        }
    }

    @Test
    func when_multipleIncomesOnSameDay_then_sortsAllIncomesBeforeOtherTypes() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let sameDay = makeDate(year: 2025, month: 6, day: 1, calendar: calendar)
        let start = DateComponents(year: 2025, month: 6)
        let end = DateComponents(year: 2025, month: 6)

        let bill = makeBill(name: "Utility", amount: 100, dueDate: sameDay, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: sameDay)

        let income1 = makeIncome(name: "Salary", amount: 2000, startDate: sameDay, in: context)
        let income2 = makeIncome(name: "Bonus", amount: 500, startDate: sameDay, in: context)
        let incomeOccurrence1 = IncomeOccurrence(from: income1, on: sameDay)
        let incomeOccurrence2 = IncomeOccurrence(from: income2, on: sameDay)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [occurrence],
            payments: [],
            incomeOccurrences: [incomeOccurrence1, incomeOccurrence2],
            from: start,
            to: end,
            calendar: calendar
        )

        let june = try #require(sections.first { $0.id == "2025-06" })
        #expect(june.items.count == 3)

        // Both incomes should come before the occurrence
        guard case .income = june.items[0] else {
            Issue.record("Expected first item to be income")
            return
        }
        guard case .income = june.items[1] else {
            Issue.record("Expected second item to be income")
            return
        }
        guard case .occurrence = june.items[2] else {
            Issue.record("Expected third item to be occurrence")
            return
        }
    }

    // MARK: - Monthly Totals Tests

    @Test
    func when_buildingWithIncomeAndBills_then_calculatesTotalsCorrectly() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let start = DateComponents(year: 2025, month: 5)
        let end = DateComponents(year: 2025, month: 5)

        let bill1 = makeBill(name: "Rent", amount: 1500, dueDate: makeDate(year: 2025, month: 5, day: 1, calendar: calendar), in: context)
        let bill2 = makeBill(name: "Utility", amount: 100, dueDate: makeDate(year: 2025, month: 5, day: 15, calendar: calendar), in: context)

        let income = makeIncome(name: "Salary", amount: 4000, startDate: makeDate(year: 2025, month: 5, day: 1, calendar: calendar), in: context)

        let occurrences = [
            BillOccurrence(bill: bill1, dueDate: bill1.dueDate),
            BillOccurrence(bill: bill2, dueDate: bill2.dueDate)
        ]
        let incomeOccurrence = IncomeOccurrence(from: income, on: income.startDate)

        let sections = CalendarSectionsBuilder.build(
            occurrences: occurrences,
            payments: [],
            incomeOccurrences: [incomeOccurrence],
            from: start,
            to: end,
            calendar: calendar
        )

        let may = try #require(sections.first { $0.id == "2025-05" })
        #expect(may.totalIncome == 4000)
        #expect(may.totalBillsDue == 1600)
        #expect(may.netRemaining == 2400)
    }

    @Test
    func when_buildingWithNoBillsOrIncome_then_totalsAreZero() {
        let calendar = utcCalendar()
        let start = DateComponents(year: 2025, month: 7)
        let end = DateComponents(year: 2025, month: 7)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [],
            payments: [],
            incomeOccurrences: [],
            from: start,
            to: end,
            calendar: calendar
        )

        let july = sections.first { $0.id == "2025-07" }
        #expect(july?.totalIncome == 0)
        #expect(july?.totalBillsDue == 0)
        #expect(july?.netRemaining == 0)
    }

    @Test
    func when_billsExceedIncome_then_netRemainingIsNegative() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let start = DateComponents(year: 2025, month: 8)
        let end = DateComponents(year: 2025, month: 8)

        let bill = makeBill(name: "BigBill", amount: 5000, dueDate: makeDate(year: 2025, month: 8, day: 15, calendar: calendar), in: context)
        let income = makeIncome(name: "SmallIncome", amount: 2000, startDate: makeDate(year: 2025, month: 8, day: 1, calendar: calendar), in: context)

        let occurrence = BillOccurrence(bill: bill, dueDate: bill.dueDate)
        let incomeOccurrence = IncomeOccurrence(from: income, on: income.startDate)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [occurrence],
            payments: [],
            incomeOccurrences: [incomeOccurrence],
            from: start,
            to: end,
            calendar: calendar
        )

        let august = try #require(sections.first { $0.id == "2025-08" })
        #expect(august.totalIncome == 2000)
        #expect(august.totalBillsDue == 5000)
        #expect(august.netRemaining == -3000)
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
private func makeBill(name: String, dueDate: Date, in context: ModelContext) -> Bill {
    let bill = Bill(name: name, amount: 50, dueDate: dueDate)
    context.insert(bill)
    return bill
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
private func makeIncome(
    name: String,
    amount: Decimal,
    startDate: Date,
    in context: ModelContext
) -> Income {
    let income = Income(
        name: name,
        amount: amount,
        currencyCode: "USD",
        startDate: startDate
    )
    context.insert(income)
    return income
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
