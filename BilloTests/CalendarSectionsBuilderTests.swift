//  Created by Jiri Urbasek on 12/05/25.

import Testing
import SwiftData
import Foundation
@testable import Billo

@MainActor
@Suite("CalendarSectionsBuilder")
struct CalendarSectionsBuilderTests {
    @Test
    func when_unpaidOccurrenceIsBeforeReferenceDate_then_createdAsMissedBill() throws {
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
        let items = january.items.filter { if case .todayDivider = $0 { false } else { true } }
        let item = try #require(items.first)
        let display = try #require(extractBill(from: item))
        #expect(display.occurrence == occurrence)
        #expect(display.status == .missed)
    }

    @Test
    func when_occurrenceIsAfterReferenceDate_then_createdAsUpcomingBill() throws {
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

        let display = try #require(extractBill(from: items[0]))
        #expect(display.occurrence == occurrence)
        #expect(display.status == .upcoming)
    }

    @Test
    func when_occurrenceIsTodayWithNoPayments_then_createdAsUpcomingBill() throws {
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

        let display = try #require(extractBill(from: items[0]))
        #expect(display.occurrence == occurrence)
        #expect(display.status == .upcoming)
    }

    @Test
    func when_occurrenceIsTodayFullyPaid_then_billSkippedPaymentShows() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let today = makeDate(year: 2025, month: 3, day: 10, calendar: calendar)
        let start = DateComponents(year: 2025, month: 3)
        let end = DateComponents(year: 2025, month: 3)

        let bill = makeBill(name: "Today", dueDate: today, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: today)
        let payment = makePayment(amount: 50, paid: today, occurrence: today, bill: bill, in: context)

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

        // Should have only a payment item, no bill item (fully paid)
        let billItems = items.compactMap { extractBill(from: $0) }
        let paymentItems = items.compactMap { extractPayment(from: $0) }
        #expect(billItems.isEmpty)
        #expect(paymentItems.count == 1)
    }

    @Test
    func when_futureOccurrencePartiallyPaid_then_billShowsAsPartiallyPaid() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let referenceDate = makeDate(year: 2025, month: 1, day: 10, calendar: calendar)
        let dueDate = makeDate(year: 2025, month: 2, day: 15, calendar: calendar)
        let paymentDate = makeDate(year: 2025, month: 1, day: 20, calendar: calendar)
        let start = DateComponents(year: 2025, month: 2)
        let end = DateComponents(year: 2025, month: 2)

        let bill = makeBill(name: "Prepaid", amount: 100, dueDate: dueDate, in: context)
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
        let display = try #require(items.compactMap({ extractBill(from: $0) }).first)
        #expect(display.status == .partiallyPaid(paid: 50, remaining: 50))
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
        // Bill A should be upcoming (payment is for bill B, not A)
        let billDisplay = try #require(items.compactMap({ extractBill(from: $0) }).first)
        #expect(billDisplay.status == .upcoming)
    }

    @Test
    func when_monthHasUnpaidBills_then_totalBillsDueIncludesAll() throws {
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
    func when_monthHasFullyPaidBill_then_totalBillsDueExcludesIt() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let referenceDate = makeDate(year: 2025, month: 5, day: 15, calendar: calendar)
        let start = DateComponents(year: 2025, month: 5)
        let end = DateComponents(year: 2025, month: 5)

        let paidBill = makeBill(name: "Paid", amount: 100, dueDate: makeDate(year: 2025, month: 5, day: 1, calendar: calendar), in: context)
        let unpaidBill = makeBill(name: "Unpaid", amount: 25, dueDate: makeDate(year: 2025, month: 5, day: 20, calendar: calendar), in: context)

        let occurrences = [
            BillOccurrence(bill: paidBill, dueDate: paidBill.dueDate),
            BillOccurrence(bill: unpaidBill, dueDate: unpaidBill.dueDate)
        ]

        let payment = makePayment(amount: 100, paid: paidBill.dueDate, occurrence: paidBill.dueDate, bill: paidBill, in: context)

        let sections = CalendarSectionsBuilder.build(
            occurrences: occurrences,
            payments: [payment],
            from: start,
            to: end,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let may = try #require(sections.first { $0.id == "2025-05" })
        #expect(may.totalBillsDue == 25, "Fully paid bill should not count toward totalBillsDue")
    }

    @Test
    func when_pastMonthHasFullyPaidBill_then_totalPaidReflectsPaymentSumAndOutstandingIsZero() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let referenceDate = makeDate(year: 2025, month: 6, day: 5, calendar: calendar)
        let start = DateComponents(year: 2025, month: 5)
        let end = DateComponents(year: 2025, month: 6)

        let dueDate = makeDate(year: 2025, month: 5, day: 10, calendar: calendar)
        let paidBill = makeBill(name: "Paid", amount: 100, dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: paidBill, dueDate: dueDate)
        let payment = makePayment(amount: 100, paid: dueDate, occurrence: dueDate, bill: paidBill, in: context)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [occurrence],
            payments: [payment],
            from: start,
            to: end,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let may = try #require(sections.first { $0.id == "2025-05" })
        #expect(may.isPast == true)
        #expect(may.totalPaid == 100)
        #expect(may.totalBillsDue == 0)
        #expect(may.netRemaining == -100)
    }

    @Test
    func when_pastMonthHasMissedUnpaidBill_then_outstandingReflectsBillAmountAndPaidIsZero() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let referenceDate = makeDate(year: 2025, month: 6, day: 5, calendar: calendar)
        let start = DateComponents(year: 2025, month: 5)
        let end = DateComponents(year: 2025, month: 6)

        let dueDate = makeDate(year: 2025, month: 5, day: 10, calendar: calendar)
        let unpaidBill = makeBill(name: "Missed", amount: 80, dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: unpaidBill, dueDate: dueDate)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [occurrence],
            payments: [],
            from: start,
            to: end,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let may = try #require(sections.first { $0.id == "2025-05" })
        #expect(may.isPast == true)
        #expect(may.totalPaid == 0)
        #expect(may.totalBillsDue == 80)
        #expect(may.netRemaining == -80)
    }

    @Test
    func when_pastMonthHasMixOfPaidAndUnpaidBills_then_paidAndOutstandingAreSeparate() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let referenceDate = makeDate(year: 2025, month: 6, day: 5, calendar: calendar)
        let start = DateComponents(year: 2025, month: 5)
        let end = DateComponents(year: 2025, month: 6)

        let paidDueDate = makeDate(year: 2025, month: 5, day: 5, calendar: calendar)
        let missedDueDate = makeDate(year: 2025, month: 5, day: 20, calendar: calendar)

        let paidBill = makeBill(name: "Paid", amount: 100, dueDate: paidDueDate, in: context)
        let missedBill = makeBill(name: "Missed", amount: 40, dueDate: missedDueDate, in: context)
        let payment = makePayment(amount: 100, paid: paidDueDate, occurrence: paidDueDate, bill: paidBill, in: context)
        let salary = makeIncome(name: "Salary", amount: 500, startDate: makeDate(year: 2025, month: 5, day: 1, calendar: calendar), in: context)
        let salaryOccurrence = IncomeOccurrenceItem(future: salary, on: salary.startDate)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [
                BillOccurrence(bill: paidBill, dueDate: paidBill.dueDate),
                BillOccurrence(bill: missedBill, dueDate: missedBill.dueDate)
            ],
            payments: [payment],
            incomeOccurrences: [salaryOccurrence],
            from: start,
            to: end,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let may = try #require(sections.first { $0.id == "2025-05" })
        #expect(may.isPast == true)
        #expect(may.totalIncome == 500)
        #expect(may.totalPaid == 100)
        #expect(may.totalBillsDue == 40)
        #expect(may.netRemaining == 360)
    }

    @Test
    func when_pastMonthHasPartiallyPaidBill_then_paidShowsActualAmountAndOutstandingShowsRemainder() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let referenceDate = makeDate(year: 2025, month: 6, day: 5, calendar: calendar)
        let start = DateComponents(year: 2025, month: 5)
        let end = DateComponents(year: 2025, month: 6)

        let dueDate = makeDate(year: 2025, month: 5, day: 10, calendar: calendar)
        let bill = makeBill(name: "Partial", amount: 100, dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: dueDate)
        let payment = makePayment(amount: 30, paid: dueDate, occurrence: dueDate, bill: bill, in: context)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [occurrence],
            payments: [payment],
            from: start,
            to: end,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let may = try #require(sections.first { $0.id == "2025-05" })
        #expect(may.isPast == true)
        #expect(may.totalPaid == 30)
        #expect(may.totalBillsDue == 70)
    }

    @Test
    func when_currentMonthHasFullyPaidBill_then_totalPaidIsZeroAndOutstandingExcludesIt() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let referenceDate = makeDate(year: 2025, month: 5, day: 15, calendar: calendar)
        let start = DateComponents(year: 2025, month: 5)
        let end = DateComponents(year: 2025, month: 5)

        let paidDueDate = makeDate(year: 2025, month: 5, day: 1, calendar: calendar)
        let unpaidDueDate = makeDate(year: 2025, month: 5, day: 20, calendar: calendar)

        let paidBill = makeBill(name: "Paid", amount: 100, dueDate: paidDueDate, in: context)
        let unpaidBill = makeBill(name: "Unpaid", amount: 25, dueDate: unpaidDueDate, in: context)
        let payment = makePayment(amount: 100, paid: paidDueDate, occurrence: paidDueDate, bill: paidBill, in: context)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [
                BillOccurrence(bill: paidBill, dueDate: paidBill.dueDate),
                BillOccurrence(bill: unpaidBill, dueDate: unpaidBill.dueDate)
            ],
            payments: [payment],
            from: start,
            to: end,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let may = try #require(sections.first { $0.id == "2025-05" })
        #expect(may.isPast == false)
        #expect(may.totalPaid == 0, "Current month must keep totalPaid at 0 to preserve original 2-color header behavior")
        #expect(may.totalBillsDue == 25)
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
        let incomeOccurrence = IncomeOccurrenceItem(future: income, on: income.startDate)

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

        // First item: missed bill
        let first = january.items[0]
        let missedBill = try #require(extractBill(from: first))
        #expect(missedBill.status == .missed)

        // Second item: today divider
        let divider = try #require(extractTodayDivider(from: january.items[1]))
        #expect(divider.date == calendar.startOfDay(for: today))
        #expect(divider.sectionId == "2025-01")

        // Third item: upcoming bill
        let upcomingBill = try #require(extractBill(from: january.items[2]))
        #expect(upcomingBill.status == .upcoming)
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
    func when_incomeAndOccurrenceOnSameDay_then_sortsIncomeFirstThenBill() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let referenceDate = makeDate(year: 2025, month: 3, day: 1, calendar: calendar)
        let sameDay = makeDate(year: 2025, month: 3, day: 15, calendar: calendar)
        let start = DateComponents(year: 2025, month: 3)
        let end = DateComponents(year: 2025, month: 3)

        let bill = makeBill(name: "Rent", amount: 1000, dueDate: sameDay, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: sameDay)
        let income = makeIncome(name: "Salary", amount: 3000, startDate: sameDay, in: context)
        let incomeOccurrence = IncomeOccurrenceItem(future: income, on: sameDay)

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

        _ = try #require(extractIncome(from: items[0]))
        _ = try #require(extractBill(from: items[1]))
    }

    @Test
    func when_paymentIsOrphanedBecauseBillWasDeleted_then_paymentStillAppearsInList() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let referenceDate = makeDate(year: 2025, month: 6, day: 20, calendar: calendar)
        let start = DateComponents(year: 2025, month: 6)
        let end = DateComponents(year: 2025, month: 6)

        let occurrenceDate = makeDate(year: 2025, month: 6, day: 10, calendar: calendar)
        let orphanPayment = try makeOrphanPaymentEntry(
            amount: 42,
            datePaid: occurrenceDate,
            occurrenceDate: occurrenceDate,
            billName: "Deleted Internet",
            calendar: calendar,
            in: context
        )

        let sections = CalendarSectionsBuilder.build(
            occurrences: [],
            payments: [orphanPayment],
            from: start,
            to: end,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let june = try #require(sections.first { $0.id == "2025-06" })
        let items = june.items.filter { if case .todayDivider = $0 { false } else { true } }
        let paymentItems = items.compactMap { extractPayment(from: $0) }
        #expect(paymentItems.count == 1)
        #expect(paymentItems.first === orphanPayment)
    }

    @Test
    func when_orphanPaymentAndLivePaymentAreInSameMonth_then_bothAppearInList() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let referenceDate = makeDate(year: 2025, month: 9, day: 20, calendar: calendar)
        let start = DateComponents(year: 2025, month: 9)
        let end = DateComponents(year: 2025, month: 9)

        let livePaymentDate = makeDate(year: 2025, month: 9, day: 12, calendar: calendar)
        let liveBill = makeBill(name: "Live", dueDate: livePaymentDate, in: context)
        let livePayment = makePayment(
            amount: 100,
            paid: livePaymentDate,
            occurrence: livePaymentDate,
            bill: liveBill,
            in: context
        )

        let orphanDate = makeDate(year: 2025, month: 9, day: 5, calendar: calendar)
        let orphanPayment = try makeOrphanPaymentEntry(
            amount: 30,
            datePaid: orphanDate,
            occurrenceDate: orphanDate,
            billName: "Deleted",
            calendar: calendar,
            in: context
        )

        let sections = CalendarSectionsBuilder.build(
            occurrences: [BillOccurrence(bill: liveBill, dueDate: livePaymentDate)],
            payments: [livePayment, orphanPayment],
            from: start,
            to: end,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let september = try #require(sections.first { $0.id == "2025-09" })
        let items = september.items.filter { if case .todayDivider = $0 { false } else { true } }
        let paymentItems = items.compactMap { extractPayment(from: $0) }
        #expect(paymentItems.contains(where: { $0 === orphanPayment }))
        #expect(paymentItems.contains(where: { $0 === livePayment }))
    }

    @Test
    func when_paymentsMadeInMonth_then_paymentItemsAppearInList() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let referenceDate = makeDate(year: 2025, month: 4, day: 10, calendar: calendar)
        let start = DateComponents(year: 2025, month: 4)
        let end = DateComponents(year: 2025, month: 4)

        let dueDate = makeDate(year: 2025, month: 4, day: 5, calendar: calendar)
        let bill = makeBill(name: "Paid", dueDate: dueDate, in: context)
        let occurrence = BillOccurrence(bill: bill, dueDate: dueDate)
        let payment = makePayment(amount: 50, paid: dueDate, occurrence: dueDate, bill: bill, in: context)

        let sections = CalendarSectionsBuilder.build(
            occurrences: [occurrence],
            payments: [payment],
            from: start,
            to: end,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let april = try #require(sections.first { $0.id == "2025-04" })
        let items = april.items.filter { if case .todayDivider = $0 { false } else { true } }
        let paymentItems = items.compactMap { extractPayment(from: $0) }
        #expect(paymentItems.count == 1, "Payment should appear in the list")
    }

    @Test
    func when_frozenPastViewAndComputedFutureViewAreInWindow_then_bothAppearWithTheirOwnAmounts() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let referenceDate = makeDate(year: 2025, month: 4, day: 15, calendar: calendar)

        let income = makeIncome(name: "Salary", amount: 1_500, startDate: makeDate(year: 2025, month: 3, day: 15, calendar: calendar), in: context)

        // Frozen past row: an old amount (1000) for March, simulating a row that
        // was materialized before the user bumped the income to 1500.
        let pastDate = makeDate(year: 2025, month: 3, day: 15, calendar: calendar)
        let snapshotKey = "\(income.stableID):2025-03-15"
        let pastModel = IncomeOccurrence(
            occurrenceKey: snapshotKey,
            date: pastDate,
            incomeName: income.name,
            incomeAmount: 1_000,
            incomeCurrencyCode: income.currencyCode,
            income: income
        )
        context.insert(pastModel)
        try context.save()

        let frozenPastView = IncomeOccurrenceItem(model: pastModel)
        let futureView = IncomeOccurrenceItem(
            future: income,
            on: makeDate(year: 2025, month: 5, day: 15, calendar: calendar)
        )

        let sections = CalendarSectionsBuilder.build(
            occurrences: [],
            payments: [],
            incomeOccurrences: [frozenPastView, futureView],
            from: DateComponents(year: 2025, month: 3),
            to: DateComponents(year: 2025, month: 5),
            referenceDate: referenceDate,
            calendar: calendar
        )

        let march = try #require(sections.first { $0.id == "2025-03" })
        let may = try #require(sections.first { $0.id == "2025-05" })
        #expect(march.totalIncome == 1_000) // frozen past amount
        #expect(may.totalIncome == 1_500)   // computed future amount
    }
}

// MARK: - Test Helpers

private func extractBill(from item: CalendarListItem) -> BillDisplay? {
    if case .bill(let display) = item {
        return display
    }
    return nil
}

private func extractPayment(from item: CalendarListItem) -> PaymentEntry? {
    if case .payment(let payment) = item {
        return payment
    }
    return nil
}

private func extractIncome(from item: CalendarListItem) -> IncomeOccurrenceItem? {
    if case .income(let view) = item {
        return view
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
    let schema = Schema([Bill.self, PaymentEntry.self, IssuedOccurrence.self, Income.self, IncomeOccurrence.self, RecurrenceRule.self])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    return ModelContext(container)
}

@MainActor
@discardableResult
private func makeBill(name: String, dueDate: Date, calendar: Calendar = utcCalendar(), in context: ModelContext) -> Bill {
    let bill = Bill(name: name, amount: 50, dueDate: dueDate, calendar: calendar)
    context.insert(bill)
    return bill
}

@MainActor
@discardableResult
private func makeBill(name: String, amount: Decimal, dueDate: Date, calendar: Calendar = utcCalendar(), in context: ModelContext) -> Bill {
    let bill = Bill(name: name, amount: amount, dueDate: dueDate, calendar: calendar)
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
) -> PaymentEntry {
    makePaymentEntry(
        amount: amount,
        datePaid: paid,
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
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return calendar.date(from: components)!
}
