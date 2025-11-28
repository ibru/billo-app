//  Created by Jiri Urbasek on 11/26/25.

import Testing
import SwiftData
import Foundation
@testable import Billo

@Suite("BillsListSections")
struct BillsListSectionsTests {
    @MainActor
    @Suite("build - Section Grouping")
    struct SectionGrouping {
        @Test func whenBillIsOverdue_thenAppearsInOverdueSection() throws {
            let (bills, referenceDate, calendar) = try makeBills(
                dueDays: [-2]
            )

            let sections = BillsListSections.build(from: bills, referenceDate: referenceDate, calendar: calendar)

            #expect(sections.occurrencesBySection[.overdue]?.count == 1)
            #expect(sections.occurrencesBySection[.overdue]?[0].name == "Bill 1")
        }

        @Test func whenBillIsDueToday_thenAppearsInTodaySection() throws {
            let (bills, referenceDate, calendar) = try makeBills(
                dueDays: [0]
            )

            let sections = BillsListSections.build(from: bills, referenceDate: referenceDate, calendar: calendar)

            #expect(sections.occurrencesBySection[.today]?.count == 1)
            #expect(sections.occurrencesBySection[.today]?[0].name == "Bill 1")
        }

        @Test func whenBillIsDueWithinSevenDays_thenAppearsInNext7DaysSection() throws {
            let (bills, referenceDate, calendar) = try makeBills(
                dueDays: [3, 5, 7]
            )

            let sections = BillsListSections.build(from: bills, referenceDate: referenceDate, calendar: calendar)

            #expect(sections.occurrencesBySection[.next7Days]?.count == 3)
        }

        @Test func whenBillIsDueWithinThirtyDays_thenAppearsInNext30DaysSection() throws {
            // Bills 8, 15, and 28 days from now should be in "Next 30 Days"
            // (beyond 7 days to avoid "Next 7 Days" section)
            let (bills, referenceDate, calendar) = try makeBills(
                dueDays: [8, 15, 28]
            )

            let sections = BillsListSections.build(from: bills, referenceDate: referenceDate, calendar: calendar)

            #expect(sections.occurrencesBySection[.next30Days]?.count == 3)
        }

        @Test func whenBillIsDueBeyondThirtyDays_thenAppearsInLaterSection() throws {
            let (bills, referenceDate, calendar) = try makeBills(
                dueDays: [35, 60]
            )

            let sections = BillsListSections.build(from: bills, referenceDate: referenceDate, calendar: calendar)

            #expect(sections.occurrencesBySection[.later]?.count == 2)
        }


        @Test func whenBillPartiallyPaidPastDue_thenStaysInOverdueBucket() throws {
            let calendar = Calendar.current
            let referenceDate = makeDate(year: 2025, month: 1, day: 10)

            let bill = Bill(name: "Bill 1", amount: 100, dueDate: makeDate(year: 2025, month: 1, day: 1))
            let payment = Payment(amount: 40, datePaid: referenceDate, occurrenceDate: bill.dueDate, bill: bill)
            let container = try ModelContainer(for: Schema([Bill.self, Payment.self]), configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
            let context = ModelContext(container)
            context.insert(bill)
            context.insert(payment)
            try context.save()

            let sections = BillsListSections.build(from: [bill], referenceDate: referenceDate, calendar: calendar)

            #expect(sections.occurrencesBySection[.overdue]?.contains { $0.name == "Bill 1" } == true)
        }

        @Test func whenBillsAcrossMultipleSections_thenGroupsCorrectly() throws {
            let (bills, referenceDate, calendar) = try makeBills(
                dueDays: [-2, 0, 3, 15, 35]
            )

            let sections = BillsListSections.build(from: bills, referenceDate: referenceDate, calendar: calendar)

            #expect(sections.occurrencesBySection[.overdue]?.count == 1)
            #expect(sections.occurrencesBySection[.today]?.count == 1)
            #expect(sections.occurrencesBySection[.next7Days]?.count == 1)
            #expect(sections.occurrencesBySection[.next30Days]?.count == 1)
            #expect(sections.occurrencesBySection[.later]?.count == 1)
        }
    }

    @MainActor
    @Suite("build - Paid Bills Handling")
    struct PaidBillsHandling {
        @Test func whenBillIsPaid_thenExcludedFromList() throws {
            let (bills, referenceDate, calendar, _) = try makeBillsWithPayment(
                dueDays: [0],
                paidIndices: [0]
            )

            let sections = BillsListSections.build(from: bills, referenceDate: referenceDate, calendar: calendar)

            #expect(sections.occurrencesBySection[.today] == nil || sections.occurrencesBySection[.today]?.isEmpty == true)
        }

        @Test func whenSomeBillsPaid_thenOnlyUnpaidShown() throws {
            let (bills, referenceDate, calendar, _) = try makeBillsWithPayment(
                dueDays: [0, 3, 5],
                paidIndices: [1]
            )

            let sections = BillsListSections.build(from: bills, referenceDate: referenceDate, calendar: calendar)

            let allOccurrences = sections.occurrencesBySection.values.flatMap { $0 }
            #expect(allOccurrences.count == 2)
            #expect(allOccurrences.contains { $0.name == "Bill 1" })
            #expect(allOccurrences.contains { $0.name == "Bill 3" })
        }
    }

    @MainActor
    @Suite("build - Recurring Bills")
    struct RecurringBills {
        @Test func whenBillIsRecurring_thenMultipleOccurrencesGenerated() throws {
            let (bills, referenceDate, calendar) = try makeBillsWithRecurrence(
                startDay: 0,
                pattern: .weekly,
                frequency: 1
            )

            let sections = BillsListSections.build(from: bills, referenceDate: referenceDate, calendar: calendar)

            let allOccurrences = sections.occurrencesBySection.values.flatMap { $0 }
            #expect(allOccurrences.count >= 3)
        }
    }

    @MainActor
    @Suite("build - Monthly Totals")
    struct MonthlyTotals {
        @Test func whenBillsInCurrentMonth_thenTotalsCalculated() throws {
            let (bills, referenceDate, calendar) = try makeBills(
                dueDays: [0, 5, 15],
                amounts: [100, 200, 300]
            )

            let sections = BillsListSections.build(from: bills, referenceDate: referenceDate, calendar: calendar)

            #expect(sections.monthlyTotals.totalDue == 600)
            #expect(sections.monthlyTotals.totalPaid == 0)
            #expect(sections.monthlyTotals.remaining == 600)
        }

        @Test func whenSomeBillsPaid_thenTotalsReflectPayments() throws {
            let (bills, referenceDate, calendar, _) = try makeBillsWithPayment(
                dueDays: [0, 5],
                amounts: [100, 200],
                paidIndices: [0]
            )

            let sections = BillsListSections.build(from: bills, referenceDate: referenceDate, calendar: calendar)

            #expect(sections.monthlyTotals.totalDue == 300)
            #expect(sections.monthlyTotals.totalPaid == 100)
            #expect(sections.monthlyTotals.remaining == 200)
        }


        @Test func whenBillPartiallyPaid_thenTotalsIncludePartial() throws {
            let calendar = Calendar.current
            let referenceDate = makeDate(year: 2025, month: 1, day: 15)

            let bill = Bill(name: "Bill 1", amount: 100, dueDate: makeDate(year: 2025, month: 1, day: 10))
            let payment = Payment(amount: 40, datePaid: referenceDate, occurrenceDate: bill.dueDate, bill: bill)

            let container = try ModelContainer(for: Schema([Bill.self, Payment.self]), configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
            let context = ModelContext(container)
            context.insert(bill)
            context.insert(payment)
            try context.save()

            let sections = BillsListSections.build(from: [bill], referenceDate: referenceDate, calendar: calendar)

            #expect(sections.monthlyTotals.totalDue == 100)
            #expect(sections.monthlyTotals.totalPaid == 40)
            #expect(sections.monthlyTotals.remaining == 60)
        }

        @Test func whenBillsOutsideCurrentMonth_thenExcludedFromTotals() throws {
            let (bills, referenceDate, calendar) = try makeBills(
                dueDays: [40, 50]
            )

            let sections = BillsListSections.build(from: bills, referenceDate: referenceDate, calendar: calendar)

            #expect(sections.monthlyTotals.totalDue == 0)
        }

        @Test func whenBillDueDateIsBeforeReferenceDate_thenStillIncludedInMonthlyTotals() throws {
            let (bills, referenceDate, calendar) = try makeBills(
                dueDays: [-5, -3, 0, 3],
                amounts: [100, 150, 200, 250]
            )

            let sections = BillsListSections.build(from: bills, referenceDate: referenceDate, calendar: calendar)

            #expect(sections.monthlyTotals.totalDue == 700)
            #expect(sections.monthlyTotals.totalPaid == 0)
            #expect(sections.monthlyTotals.remaining == 700)
        }

        @Test func whenBillDueDateIsExactlyMonthStart_thenIncludedInTotals() throws {
            let calendar = Calendar.current
            let referenceDate = makeDate(year: 2025, month: 1, day: 15)
            let monthStart = calendar.dateInterval(of: .month, for: referenceDate)!.start

            let bill = Bill(
                name: "Test Bill",
                amount: 500,
                dueDate: monthStart
            )

            let sections = BillsListSections.build(from: [bill], referenceDate: referenceDate, calendar: calendar)

            #expect(sections.monthlyTotals.totalDue == 500)
        }

        @Test func whenBillDueDateIsExactlyMonthEnd_thenExcludedFromTotals() throws {
            let calendar = Calendar.current
            let referenceDate = makeDate(year: 2025, month: 1, day: 15)
            let monthEnd = calendar.dateInterval(of: .month, for: referenceDate)!.end

            let bill = Bill(
                name: "Test Bill",
                amount: 500,
                dueDate: monthEnd
            )

            let sections = BillsListSections.build(from: [bill], referenceDate: referenceDate, calendar: calendar)

            #expect(sections.monthlyTotals.totalDue == 0)
        }

        @Test func whenRecurringBillHasMultipleOccurrencesInMonth_thenAllIncludedInTotals() throws {
            let calendar = Calendar.current
            let referenceDate = makeDate(year: 2025, month: 1, day: 15)
            let startDate = makeDate(year: 2025, month: 1, day: 1)

            let recurrenceRule = RecurrenceRule(pattern: .weekly, frequency: 1)
            let bill = Bill(
                name: "Weekly Bill",
                amount: 50,
                dueDate: startDate,
                recurrenceRule: recurrenceRule
            )

            let sections = BillsListSections.build(from: [bill], referenceDate: referenceDate, calendar: calendar)

            #expect(sections.monthlyTotals.totalDue >= 200)
        }

        @Test func whenMixOfPaidAndUnpaidBills_thenTotalsCorrect() throws {
            let (bills, referenceDate, calendar, _) = try makeBillsWithPayment(
                dueDays: [0, 3, 7, 10],
                amounts: [100, 200, 300, 400],
                paidIndices: [0, 2]
            )

            let sections = BillsListSections.build(from: bills, referenceDate: referenceDate, calendar: calendar)

            #expect(sections.monthlyTotals.totalDue == 1000)
            #expect(sections.monthlyTotals.totalPaid == 400)
            #expect(sections.monthlyTotals.remaining == 600)
        }

        @Test func whenUpcomingBillsFallOutsideCalendarMonth_thenMonthlyTotalsRemainZero() throws {
            let (bills, referenceDate, calendar) = try makeBills(
                dueDays: [10],
                referenceDay: 28
            )

            let sections = BillsListSections.build(from: bills, referenceDate: referenceDate, calendar: calendar)

            #expect(sections.occurrencesBySection[.next30Days]?.count == 1)
            #expect(sections.monthlyTotals.totalDue == 0)
            #expect(sections.monthlyTotals.remaining == 0)
        }
    }

    @MainActor
    @Suite("build - Sorting")
    struct Sorting {
        @Test func whenMultipleBillsInSection_thenSortedByDueDate() throws {
            let (bills, referenceDate, calendar) = try makeBills(
                dueDays: [7, 3, 5]
            )

            let sections = BillsListSections.build(from: bills, referenceDate: referenceDate, calendar: calendar)

            let next7DaysOccurrences = sections.occurrencesBySection[.next7Days] ?? []
            #expect(next7DaysOccurrences.count == 3)
            #expect(next7DaysOccurrences[0].name == "Bill 2")
            #expect(next7DaysOccurrences[1].name == "Bill 3")
            #expect(next7DaysOccurrences[2].name == "Bill 1")
        }
    }
}

// MARK: - makeSUT & Factories

private func makeBills(
    dueDays: [Int],
    amounts: [Decimal]? = nil,
    referenceDay: Int = 15
) throws -> ([Bill], Date, Calendar) {
    let calendar = Calendar.current
    let referenceDate = makeDate(year: 2025, month: 1, day: referenceDay)

    let bills = dueDays.enumerated().map { index, dayOffset in
        let dueDate = calendar.date(byAdding: .day, value: dayOffset, to: referenceDate)!
        let amount = amounts?[index] ?? Decimal(100)
        return Bill(
            name: "Bill \(index + 1)",
            amount: amount,
            dueDate: dueDate
        )
    }

    return (bills, referenceDate, calendar)
}

private func makeBillsWithPayment(
    dueDays: [Int],
    amounts: [Decimal]? = nil,
    paidIndices: [Int],
    referenceDay: Int = 15
) throws -> ([Bill], Date, Calendar, ModelContext) {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Bill.self, Payment.self, configurations: config)
    let modelContext = ModelContext(container)

    let calendar = Calendar.current
    let referenceDate = makeDate(year: 2025, month: 1, day: referenceDay)

    let bills = dueDays.enumerated().map { index, dayOffset in
        let dueDate = calendar.date(byAdding: .day, value: dayOffset, to: referenceDate)!
        let amount = amounts?[index] ?? Decimal(100)
        let bill = Bill(
            name: "Bill \(index + 1)",
            amount: amount,
            dueDate: dueDate
        )
        modelContext.insert(bill)

        if paidIndices.contains(index) {
            let payment = Payment(
                amount: bill.amount,
                datePaid: referenceDate,
                occurrenceDate: dueDate,
                bill: bill
            )
            modelContext.insert(payment)
        }

        return bill
    }

    try modelContext.save()

    return (bills, referenceDate, calendar, modelContext)
}

private func makeBillsWithRecurrence(
    startDay: Int,
    pattern: RepeatIntervalType,
    frequency: Int,
    referenceDay: Int = 15
) throws -> ([Bill], Date, Calendar) {
    let calendar = Calendar.current
    let referenceDate = makeDate(year: 2025, month: 1, day: referenceDay)
    let dueDate = calendar.date(byAdding: .day, value: startDay, to: referenceDate)!

    let recurrenceRule = RecurrenceRule(pattern: pattern, frequency: frequency)
    let bill = Bill(
        name: "Recurring Bill",
        amount: 100,
        dueDate: dueDate,
        recurrenceRule: recurrenceRule
    )

    return ([bill], referenceDate, calendar)
}

private func makeDate(year: Int = 2025, month: Int = 1, day: Int) -> Date {
    let calendar = Calendar.current
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return calendar.date(from: components)!
}
