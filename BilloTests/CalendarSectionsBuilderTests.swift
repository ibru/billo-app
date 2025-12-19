//  Created by Jiri Urbasek on 12/05/25.

import Testing
import SwiftData
import Foundation
@testable import Billo

@MainActor
@Suite("CalendarSectionsBuilder")
struct CalendarSectionsBuilderTests {
    @Test
    func when_occurrenceIsBeforeReferenceDate_then_createdAsPastOccurrence() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let referenceDate = makeDate(year: 2025, month: 1, day: 10, calendar: calendar)
        let dueDate = makeDate(year: 2025, month: 1, day: 5, calendar: calendar)
        let start = DateComponents(year: 2025, month: 1)
        let end = DateComponents(year: 2025, month: 1)

        let bill = makeBill(name: "Rent", dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: dueDate)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [occurrence],
            payments: [],
            from: start,
            to: end,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let january = try #require(sections.first { $0.id == "2025-01" })
        let item = try #require(january.items.first)
        let display: PastBillDisplay = try #require(extractPastOccurrence(from: item))
        #expect(display.occurrence == occurrence)
    }

    @Test
    func when_occurrenceIsAfterReferenceDate_then_createdAsOccurrence() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let referenceDate = makeDate(year: 2025, month: 1, day: 10, calendar: calendar)
        let dueDate = makeDate(year: 2025, month: 1, day: 15, calendar: calendar)
        let start = DateComponents(year: 2025, month: 1)
        let end = DateComponents(year: 2025, month: 1)

        let bill = makeBill(name: "Future", dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: dueDate)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [occurrence],
            payments: [],
            from: start,
            to: end,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let january = try #require(sections.first { $0.id == "2025-01" })
        let items = january.items.filter { if case .todayDivider = $0 { false } else { true } }
        try #require(items.count == 1)

        let item = try requireItem(items, at: 0)
        let extracted = try #require(extractOccurrence(from: item))
        let builtOccurrence = extracted.occurrence
        let payments = extracted.payments
        #expect(builtOccurrence == occurrence)
        #expect(payments.isEmpty)
    }

    @Test
    func when_occurrenceIsTodayWithNoPayments_then_createdAsOccurrence() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let today = makeDate(year: 2025, month: 2, day: 10, calendar: calendar)
        let start = DateComponents(year: 2025, month: 2)
        let end = DateComponents(year: 2025, month: 2)

        let bill = makeBill(name: "Today", dueDate: today, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: today)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [occurrence],
            payments: [],
            from: start,
            to: end,
            referenceDate: today,
            calendar: calendar
        )

        let february = try #require(sections.first { $0.id == "2025-02" })
        let items = february.items.filter { if case .todayDivider = $0 { false } else { true } }
        try #require(items.count == 1)

        let item = try requireItem(items, at: 0)
        let extracted = try #require(extractOccurrence(from: item))
        let builtOccurrence = extracted.occurrence
        let payments = extracted.payments
        #expect(builtOccurrence == occurrence)
        #expect(payments.isEmpty)
    }

    @Test
    func when_occurrenceIsTodayWithPayments_then_createdAsPastOccurrence() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let today = makeDate(year: 2025, month: 3, day: 10, calendar: calendar)
        let start = DateComponents(year: 2025, month: 3)
        let end = DateComponents(year: 2025, month: 3)

        let bill = makeBill(name: "Today", dueDate: today, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: today)
        let payment = makePayment(amount: 10, paid: today, occurrence: today, bill: bill, in: context)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [occurrence],
            payments: [payment],
            from: start,
            to: end,
            referenceDate: today,
            calendar: calendar
        )

        let march = try #require(sections.first { $0.id == "2025-03" })
        let items = march.items.filter { if case .todayDivider = $0 { false } else { true } }
        try #require(items.count == 1)

        let item = try requireItem(items, at: 0)
        let display = try #require(extractPastOccurrence(from: item))
        #expect(display.occurrence == occurrence)
        #expect(display.payments.count == 1)
    }

    @Test
    func when_futureOccurrenceHasPayments_then_paymentsIncludedInOccurrence() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let referenceDate = makeDate(year: 2025, month: 1, day: 10, calendar: calendar)
        let dueDate = makeDate(year: 2025, month: 2, day: 15, calendar: calendar)
        let paymentDate = makeDate(year: 2025, month: 1, day: 20, calendar: calendar)
        let start = DateComponents(year: 2025, month: 2)
        let end = DateComponents(year: 2025, month: 2)

        let bill = makeBill(name: "Prepaid", dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: dueDate)
        let payment = makePayment(amount: 50, paid: paymentDate, occurrence: dueDate, bill: bill, in: context)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [occurrence],
            payments: [payment],
            from: start,
            to: end,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let february = try #require(sections.first { $0.id == "2025-02" })
        let items = february.items.filter { if case .todayDivider = $0 { false } else { true } }
        let item = try #require(items.first)
        let extracted = try #require(extractOccurrence(from: item))
        let payments = extracted.payments
        #expect(payments.count == 1)
    }

    @Test
    func when_paymentForDifferentBill_then_notAssociatedWithOccurrence() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let referenceDate = makeDate(year: 2025, month: 1, day: 1, calendar: calendar)
        let dueDate = makeDate(year: 2025, month: 1, day: 15, calendar: calendar)
        let start = DateComponents(year: 2025, month: 1)
        let end = DateComponents(year: 2025, month: 1)

        let bill = makeBill(name: "A", dueDate: dueDate, in: context)
        let otherBill = makeBill(name: "B", dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: dueDate)
        let otherBillPayment = makePayment(amount: 10, paid: dueDate, occurrence: dueDate, bill: otherBill, in: context)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [occurrence],
            payments: [otherBillPayment],
            from: start,
            to: end,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let january = try #require(sections.first { $0.id == "2025-01" })
        let items = january.items.filter { if case .todayDivider = $0 { false } else { true } }
        let item = try #require(items.first)
        let extracted = try #require(extractOccurrence(from: item))
        let payments = extracted.payments
        #expect(payments.isEmpty)
    }

    @Test
    func when_paymentForDifferentOccurrenceDate_then_notAssociatedWithOccurrence() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let referenceDate = makeDate(year: 2025, month: 1, day: 1, calendar: calendar)
        let dueDate = makeDate(year: 2025, month: 1, day: 15, calendar: calendar)
        let otherDueDate = makeDate(year: 2025, month: 1, day: 16, calendar: calendar)
        let start = DateComponents(year: 2025, month: 1)
        let end = DateComponents(year: 2025, month: 1)

        let bill = makeBill(name: "A", dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: dueDate)
        let payment = makePayment(amount: 10, paid: dueDate, occurrence: otherDueDate, bill: bill, in: context)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [occurrence],
            payments: [payment],
            from: start,
            to: end,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let january = try #require(sections.first { $0.id == "2025-01" })
        let items = january.items.filter { if case .todayDivider = $0 { false } else { true } }
        let item = try #require(items.first)
        let extracted = try #require(extractOccurrence(from: item))
        let payments = extracted.payments
        #expect(payments.isEmpty)
    }

    @Test
    func when_monthHasPastAndFutureOccurrences_then_totalBillsDueIncludesAll() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let referenceDate = makeDate(year: 2025, month: 5, day: 15, calendar: calendar)
        let start = DateComponents(year: 2025, month: 5)
        let end = DateComponents(year: 2025, month: 5)

        let pastBill = makeBill(name: "Past", amount: 10, dueDate: makeDate(year: 2025, month: 5, day: 1, calendar: calendar), in: context)
        let futureBill = makeBill(name: "Future", amount: 25, dueDate: makeDate(year: 2025, month: 5, day: 20, calendar: calendar), in: context)

        let occurrences = [
            BillOccurrence(bill: pastBill, dueDate: pastBill.dueDate),
            BillOccurrence(bill: futureBill, dueDate: futureBill.dueDate)
        ]

        let sections = CalendarSectionsBuilder.build(
            occurrences: occurrences,
            payments: [],
            from: start,
            to: end,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let may = try #require(sections.first { $0.id == "2025-05" })
        #expect(may.totalBillsDue == 35)
    }

    @Test
    func when_buildingWithNoBillsOrIncome_then_totalsAreZero() {
        let calendar = utcCalendar()
        let referenceDate = makeDate(year: 2025, month: 7, day: 10, calendar: calendar)
        let start = DateComponents(year: 2025, month: 7)
        let end = DateComponents(year: 2025, month: 7)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [],
            payments: [],
            incomeOccurrences: [],
            from: start,
            to: end,
            referenceDate: referenceDate,
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
        let referenceDate = makeDate(year: 2025, month: 8, day: 10, calendar: calendar)
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
            referenceDate: referenceDate,
            calendar: calendar
        )

        let august = try #require(sections.first { $0.id == "2025-08" })
        #expect(august.totalIncome == 2000)
        #expect(august.totalBillsDue == 5000)
        #expect(august.netRemaining == -3000)
    }

    @Test
    func when_buildingWithEmptyMonth_then_insertsEmptyMonthPlaceholderWithUniqueSectionId() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let referenceDate = makeDate(year: 2025, month: 1, day: 1, calendar: calendar)
        let start = DateComponents(year: 2025, month: 1)
        let end = DateComponents(year: 2025, month: 3)

        let bill = makeBill(name: "OneTime", dueDate: makeDate(year: 2025, month: 1, day: 2, calendar: calendar), in: context)
        let occurrences = [BillOccurrence(bill: bill, dueDate: bill.dueDate)]

        let sections = CalendarSectionsBuilder.build(
            occurrences: occurrences,
            payments: [],
            from: start,
            to: end,
            referenceDate: referenceDate,
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
        let referenceDate = makeDate(year: 2024, month: 12, day: 1, calendar: calendar)
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
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(sections.count == 2)
        #expect(sections.map(\.id) == ["2024-12", "2025-01"])
    }

    @Test
    func when_occurrenceAndPastOccurrenceOnSameDay_then_sortedByIdForStability() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let today = makeDate(year: 2025, month: 6, day: 10, calendar: calendar)
        let start = DateComponents(year: 2025, month: 6)
        let end = DateComponents(year: 2025, month: 6)

        let paidBill = makeBill(name: "Paid", dueDate: today, in: context)
        let unpaidBill = makeBill(name: "Unpaid", dueDate: today, in: context)

        let paidOccurrence = BillOccurrence(bill: paidBill, dueDate: today)
        let unpaidOccurrence = BillOccurrence(bill: unpaidBill, dueDate: today)
        let payment = makePayment(amount: 10, paid: today, occurrence: today, bill: paidBill, in: context)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [paidOccurrence, unpaidOccurrence],
            payments: [payment],
            from: start,
            to: end,
            referenceDate: today,
            calendar: calendar
        )

        let june = try #require(sections.first { $0.id == "2025-06" })
        let items = june.items.filter { if case .todayDivider = $0 { false } else { true } }
        #expect(items.count == 2)

        let ids = items.map(\.id)
        #expect(ids == ids.sorted())
    }

    @Test
    func when_monthContainsToday_then_insertsTodayDividerBeforeFirstItemOnOrAfterToday() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let today = makeDate(year: 2025, month: 1, day: 15, calendar: calendar)
        let start = DateComponents(year: 2025, month: 1)
        let end = DateComponents(year: 2025, month: 1)

        let pastDueDate = makeDate(year: 2025, month: 1, day: 10, calendar: calendar)
        let futureDueDate = makeDate(year: 2025, month: 1, day: 20, calendar: calendar)

        let pastBill = makeBill(name: "Past", amount: 10, dueDate: pastDueDate, in: context)
        let futureBill = makeBill(name: "Future", amount: 10, dueDate: futureDueDate, in: context)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [
                BillOccurrence(bill: pastBill, dueDate: pastDueDate),
                BillOccurrence(bill: futureBill, dueDate: futureDueDate)
            ],
            payments: [],
            from: start,
            to: end,
            referenceDate: today,
            calendar: calendar
        )

        let january = try #require(sections.first { $0.id == "2025-01" })
        try #require(january.items.count == 3)

        let first = try requireItem(january.items, at: 0)
        _ = try #require(extractPastOccurrence(from: first))

        let second = try requireItem(january.items, at: 1)
        let divider = try #require(extractTodayDivider(from: second))
        let dividerDate = divider.date
        let sectionId = divider.sectionId
        #expect(dividerDate == calendar.startOfDay(for: today))
        #expect(sectionId == "2025-01")

        let third = try requireItem(january.items, at: 2)
        _ = try #require(extractOccurrence(from: third))
    }

    @Test
    func when_allItemsAreBeforeToday_then_todayDividerNotInserted() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let today = makeDate(year: 2025, month: 1, day: 20, calendar: calendar)
        let start = DateComponents(year: 2025, month: 1)
        let end = DateComponents(year: 2025, month: 1)

        let pastDueDate = makeDate(year: 2025, month: 1, day: 10, calendar: calendar)
        let pastBill = makeBill(name: "Past", amount: 10, dueDate: pastDueDate, in: context)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [BillOccurrence(bill: pastBill, dueDate: pastDueDate)],
            payments: [],
            from: start,
            to: end,
            referenceDate: today,
            calendar: calendar
        )

        let january = try #require(sections.first { $0.id == "2025-01" })
        #expect(january.items.count == 1)
        #expect(january.items.contains { if case .todayDivider = $0 { true } else { false } } == false)
    }

    @Test
    func when_multipleEmptyMonths_then_eachHasUniqueId() {
        let calendar = utcCalendar()
        let referenceDate = makeDate(year: 2025, month: 5, day: 10, calendar: calendar)
        let start = DateComponents(year: 2025, month: 5)
        let end = DateComponents(year: 2025, month: 7)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [],
            payments: [],
            from: start,
            to: end,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let ids = sections.flatMap { section in section.items.map(\.id) }
        #expect(Set(ids).count == ids.count)
    }

    @Test
    func when_incomeAndOccurrenceOnSameDay_then_sortsIncomeFirstThenOccurrence() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let referenceDate = makeDate(year: 2025, month: 3, day: 1, calendar: calendar)
        let sameDay = makeDate(year: 2025, month: 3, day: 15, calendar: calendar)
        let start = DateComponents(year: 2025, month: 3)
        let end = DateComponents(year: 2025, month: 3)

        let bill = makeBill(name: "Rent", amount: 1000, dueDate: sameDay, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: sameDay)
        let income = makeIncome(name: "Salary", amount: 3000, startDate: sameDay, in: context)
        let incomeOccurrence = IncomeOccurrence(from: income, on: sameDay)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [occurrence],
            payments: [],
            incomeOccurrences: [incomeOccurrence],
            from: start,
            to: end,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let march = try #require(sections.first { $0.id == "2025-03" })
        let items = march.items.filter { if case .todayDivider = $0 { false } else { true } }
        try #require(items.count == 2)

        let first = try requireItem(items, at: 0)
        _ = try #require(extractIncome(from: first))

        let second = try requireItem(items, at: 1)
        _ = try #require(extractOccurrence(from: second))
    }
}

// MARK: - Test Helpers

private func requireItem(_ items: [CalendarListItem], at index: Int) throws -> CalendarListItem {
    let item: CalendarListItem? = items.indices.contains(index) ? items[index] : nil
    return try #require(item)
}

private func extractOccurrence(from item: CalendarListItem) -> (occurrence: BillOccurrence, payments: [Payment])? {
    if case .occurrence(let occurrence, let payments) = item {
        return (occurrence: occurrence, payments: payments)
    }
    return nil
}

private func extractPastOccurrence(from item: CalendarListItem) -> PastBillDisplay? {
    if case .pastOccurrence(let display) = item {
        return display
    }
    return nil
}

private func extractIncome(from item: CalendarListItem) -> IncomeOccurrence? {
    if case .income(let income) = item {
        return income
    }
    return nil
}

private func extractTodayDivider(from item: CalendarListItem) -> (date: Date, sectionId: String)? {
    if case .todayDivider(let date, let sectionId) = item {
        return (date: date, sectionId: sectionId)
    }
    return nil
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
