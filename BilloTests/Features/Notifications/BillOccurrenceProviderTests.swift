//  Created by Jiri Urbasek on 12/03/25.

import Testing
import SwiftData
import Foundation
@testable import Billo

@Suite("BillOccurrenceProvider - Notification Bug Fix")
@MainActor
struct BillOccurrenceProviderTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.locale = Locale(identifier: "en_US")
        return cal
    }()

    @Test
    func whenMonthlyBillDueOn20thAndTodayIs3rd_thenNoTodayOccurrenceGenerated() async throws {
        // Given: Monthly bill due on 20th
        let bill = try makeBill(dueDate: makeDate(day: 20), recurrence: .monthly)
        let referenceDate = makeDate(day: 3)  // Today is the 3rd

        // When: Generate unpaid occurrences
        let sut = BillOccurrenceProvider()
        let occurrences = await sut.unpaidOccurrences(
            from: [bill],
            referenceDate: referenceDate,
            horizonDays: 90,
            calendar: calendar
        )

        // Then: Should NOT contain today (the 3rd)
        let hasToday = occurrences.contains { occ in
            calendar.isDate(occ.dueDate, inSameDayAs: referenceDate)
        }
        #expect(!hasToday, "Should not generate a fake 'today' occurrence")

        // And: First occurrence should be on the 20th
        let first = try #require(occurrences.first)
        let day = calendar.component(.day, from: first.dueDate)
        #expect(day == 20, "First occurrence should be on the 20th, got \(day)")
    }

    @Test
    func whenOneTimeBillDueOn10thAndTodayIs3rd_thenOccurrenceIs10th() async throws {
        // Given: One-time bill due on 10th
        let bill = try makeBill(dueDate: makeDate(day: 10), recurrence: nil)
        let referenceDate = makeDate(day: 3)  // Today is the 3rd

        // When: Generate unpaid occurrences
        let sut = BillOccurrenceProvider()
        let occurrences = await sut.unpaidOccurrences(
            from: [bill],
            referenceDate: referenceDate,
            horizonDays: 90,
            calendar: calendar
        )

        // Then: Should have exactly one occurrence
        #expect(occurrences.count == 1, "One-time bill should have exactly one occurrence")

        // And: It should be on the 10th
        let occurrence = try #require(occurrences.first)
        let day = calendar.component(.day, from: occurrence.dueDate)
        #expect(day == 10, "Occurrence should be on the 10th, got \(day)")
    }

    @Test
    func whenWeeklyBillDueOnMondayAndTodayIsFriday_thenNoTodayOccurrenceGenerated() async throws {
        // Given: Weekly bill due on Monday (Jan 6, 2025)
        let bill = try makeBill(
            dueDate: makeDate(year: 2025, month: 1, day: 6),  // Monday
            recurrence: .weekly
        )
        let referenceDate = makeDate(year: 2025, month: 1, day: 10)  // Friday

        // When: Generate unpaid occurrences
        let sut = BillOccurrenceProvider()
        let occurrences = await sut.unpaidOccurrences(
            from: [bill],
            referenceDate: referenceDate,
            horizonDays: 90,
            calendar: calendar
        )

        // Then: Should NOT contain today (Friday)
        let hasToday = occurrences.contains { occ in
            calendar.isDate(occ.dueDate, inSameDayAs: referenceDate)
        }
        #expect(!hasToday, "Should not generate a fake 'today' occurrence")

        // And: All occurrences should be on Monday
        let expectedWeekday = calendar.component(.weekday, from: bill.dueDate)
        for occurrence in occurrences {
            let weekday = calendar.component(.weekday, from: occurrence.dueDate)
            #expect(weekday == expectedWeekday, "Expected weekday \(expectedWeekday), got \(weekday)")
        }
    }

    @Test
    func whenBillIsDueToday_thenTodayOccurrenceIsIncluded() async throws {
        // Given: Monthly bill due on the 10th, and today is the 10th
        let bill = try makeBill(dueDate: makeDate(day: 10), recurrence: .monthly)
        let referenceDate = makeDate(day: 10)  // Today is the 10th (due date)

        // When: Generate unpaid occurrences
        let sut = BillOccurrenceProvider()
        let occurrences = await sut.unpaidOccurrences(
            from: [bill],
            referenceDate: referenceDate,
            horizonDays: 90,
            calendar: calendar
        )

        // Then: Should include today's occurrence (positive case)
        let hasToday = occurrences.contains { occ in
            calendar.isDate(occ.dueDate, inSameDayAs: referenceDate)
        }
        #expect(hasToday, "Bill due today should be included in occurrences")

        // And: The occurrence should be on the 10th
        let todayOccurrence = try #require(occurrences.first(where: { calendar.isDate($0.dueDate, inSameDayAs: referenceDate) }))
        let day = calendar.component(.day, from: todayOccurrence.dueDate)
        #expect(day == 10, "Today's occurrence should be on the 10th")
    }

    @Test
    func whenBillIsOverdue_thenOverdueOccurrenceIsIncluded() async throws {
        // Given: Monthly bill due on the 5th, today is the 10th (5 days overdue)
        let bill = try makeBill(dueDate: makeDate(day: 5), recurrence: .monthly)
        let referenceDate = makeDate(day: 10)  // Today is the 10th

        // When: Generate unpaid occurrences
        let sut = BillOccurrenceProvider()
        let occurrences = await sut.unpaidOccurrences(
            from: [bill],
            referenceDate: referenceDate,
            horizonDays: 90,
            calendar: calendar
        )

        // Then: Should include the overdue occurrence from the 5th
        let hasOverdue = occurrences.contains { occ in
            let day = calendar.component(.day, from: occ.dueDate)
            return day == 5
        }
        #expect(hasOverdue, "Overdue bill from the 5th should be included")

        // And: Should also include the next occurrence (next month on the 5th)
        #expect(occurrences.count >= 2, "Should include both overdue and future occurrences")
    }

    @Test
    func whenWeeklyBillNotDueToday_thenNoFakeTodayOccurrence() async throws {
        // Given: Weekly bill starting on Dec 1 (Monday), today is Dec 3 (Wednesday)
        let bill = try makeBill(
            dueDate: makeDate(year: 2025, month: 12, day: 1),  // Monday
            recurrence: .weekly
        )
        let referenceDate = makeDate(year: 2025, month: 12, day: 3)  // Wednesday

        // When: Generate unpaid occurrences
        let sut = BillOccurrenceProvider()
        let occurrences = await sut.unpaidOccurrences(
            from: [bill],
            referenceDate: referenceDate,
            horizonDays: 30,  // Check next month
            calendar: calendar
        )

        // Then: Each date should be exactly once (no duplicates)
        let uniqueDates = Set(occurrences.map { calendar.startOfDay(for: $0.dueDate) })
        #expect(uniqueDates.count == occurrences.count, "Should not have duplicate occurrences for the same day")

        // And: Should NOT include the 3rd (Wednesday) since bill is due on Mondays
        let hasToday = occurrences.contains { occ in
            calendar.isDate(occ.dueDate, inSameDayAs: referenceDate)
        }
        #expect(!hasToday, "Weekly bill should not include today if not due today")

        // And: Should include the 1st (first Monday occurrence)
        let hasFirstDue = occurrences.contains { occ in
            let day = calendar.component(.day, from: occ.dueDate)
            let month = calendar.component(.month, from: occ.dueDate)
            return day == 1 && month == 12
        }
        #expect(hasFirstDue, "Weekly bill should include first due date occurrence")
    }

    @Test
    func whenBillHasYearsOfHistory_thenOnlyRecentOccurrencesIncluded() async throws {
        // Given: Monthly bill from 3 years ago (2022), never paid
        let bill = try makeBill(
            dueDate: makeDate(year: 2022, month: 1, day: 15),
            recurrence: .monthly
        )
        let referenceDate = makeDate(year: 2025, month: 12, day: 10)

        // When: Generate unpaid occurrences for next 90 days
        let sut = BillOccurrenceProvider()
        let occurrences = await sut.unpaidOccurrences(
            from: [bill],
            referenceDate: referenceDate,
            horizonDays: 90,
            calendar: calendar
        )

        // Then: Should NOT include ancient history (36+ months of occurrences)
        // For monthly bills, lookback is 24 months max
        let oldestYear = occurrences.map { calendar.component(.year, from: $0.dueDate) }.min()
        #expect(oldestYear ?? 2025 >= 2023, "Should not include occurrences from 2022 (beyond lookback window)")

        // And: Should have reasonable count (not 36+ months of history)
        // 24 months lookback + 3 months lookahead = ~27 occurrences max for monthly
        #expect(occurrences.count <= 30, "Should not include years of unbounded history, got \(occurrences.count)")

        // And: Should include recent overdue occurrences within lookback window
        let hasRecentOverdue = occurrences.contains { occ in
            let year = calendar.component(.year, from: occ.dueDate)
            return year >= 2023 && occ.dueDate < referenceDate
        }
        #expect(hasRecentOverdue, "Should include recent overdue occurrences within lookback window")
    }

    @Test
    func whenOccurrenceIsFullyPaid_thenThatOccurrenceIsExcluded() async throws {
        let dueDate = makeDate(day: 10)
        let referenceDate = makeDate(day: 10)
        let (bill, context) = try makeBillWithContext(dueDate: dueDate, recurrence: .monthly)

        _ = makePaymentEntry(
            amount: 100,
            datePaid: referenceDate,
            occurrenceDate: dueDate,
            bill: bill,
            calendar: calendar,
            in: context
        )
        try context.save()

        let sut = BillOccurrenceProvider()
        let occurrences = await sut.unpaidOccurrences(
            from: [bill],
            referenceDate: referenceDate,
            horizonDays: 90,
            calendar: calendar
        )

        let includesPaidOccurrence = occurrences.contains { calendar.isDate($0.dueDate, inSameDayAs: dueDate) }
        #expect(!includesPaidOccurrence, "Fully paid occurrence should not be returned as unpaid")
        #expect(occurrences.contains { $0.dueDate > dueDate }, "Should still include future unpaid occurrences")
    }

    @Test
    func whenOccurrenceIsPartiallyPaid_thenOccurrenceIsStillIncluded() async throws {
        let dueDate = makeDate(day: 10)
        let referenceDate = makeDate(day: 10)
        let (bill, context) = try makeBillWithContext(dueDate: dueDate, recurrence: .monthly)

        _ = makePaymentEntry(
            amount: 50,
            datePaid: referenceDate,
            occurrenceDate: dueDate,
            bill: bill,
            calendar: calendar,
            in: context
        )
        try context.save()

        let sut = BillOccurrenceProvider()
        let occurrences = await sut.unpaidOccurrences(
            from: [bill],
            referenceDate: referenceDate,
            horizonDays: 90,
            calendar: calendar
        )

        let includesPartiallyPaidOccurrence = occurrences.contains { calendar.isDate($0.dueDate, inSameDayAs: dueDate) }
        #expect(includesPartiallyPaidOccurrence, "Partially paid occurrence should still be returned as unpaid")
    }

    @Test
    func whenMultiplePartialPaymentsSumToFull_thenOccurrenceIsExcluded() async throws {
        let dueDate = makeDate(day: 10)
        let referenceDate = makeDate(day: 10)
        let (bill, context) = try makeBillWithContext(dueDate: dueDate, recurrence: .monthly)

        _ = makePaymentEntry(
            amount: 60,
            datePaid: referenceDate,
            occurrenceDate: dueDate,
            bill: bill,
            calendar: calendar,
            in: context
        )
        _ = makePaymentEntry(
            amount: 40,
            datePaid: referenceDate,
            occurrenceDate: dueDate,
            bill: bill,
            calendar: calendar,
            in: context
        )
        try context.save()

        let sut = BillOccurrenceProvider()
        let occurrences = await sut.unpaidOccurrences(
            from: [bill],
            referenceDate: referenceDate,
            horizonDays: 90,
            calendar: calendar
        )

        let includesPaidOccurrence = occurrences.contains { calendar.isDate($0.dueDate, inSameDayAs: dueDate) }
        #expect(!includesPaidOccurrence, "Occurrence should be excluded once sum(payments) reaches bill amount")
    }

    @Test
    func whenBillsIsEmpty_thenReturnsEmpty() async throws {
        let sut = BillOccurrenceProvider()
        let occurrences = await sut.unpaidOccurrences(
            from: [],
            referenceDate: makeDate(day: 10),
            horizonDays: 90,
            calendar: calendar
        )
        #expect(occurrences.isEmpty)
    }

    @Test
    func whenHorizonIsZero_thenFutureOccurrencesAreExcludedButOverdueIncluded() async throws {
        let bill = try makeBill(dueDate: makeDate(day: 5), recurrence: .monthly)
        let referenceDate = makeDate(day: 10)

        let sut = BillOccurrenceProvider()
        let occurrences = await sut.unpaidOccurrences(
            from: [bill],
            referenceDate: referenceDate,
            horizonDays: 0,
            calendar: calendar
        )

        let hasOverdue5th = occurrences.contains { calendar.isDate($0.dueDate, inSameDayAs: makeDate(day: 5)) }
        #expect(hasOverdue5th, "Overdue occurrence should still be included when horizonDays is 0")

        let hasFutureOccurrence = occurrences.contains { $0.dueDate > referenceDate }
        #expect(!hasFutureOccurrence, "Future occurrences should be excluded when horizonDays is 0")
    }

    @Test
    func whenRecurrenceHasEndDate_thenNoOccurrencesAfterEndDate() async throws {
        let dueDate = makeDate(year: 2025, month: 12, day: 1)
        let endDate = makeDate(year: 2026, month: 2, day: 1)
        let referenceDate = makeDate(year: 2025, month: 12, day: 10)

        let (bill, _) = try makeBillWithContext(
            dueDate: dueDate,
            recurrence: .monthly,
            endDate: endDate
        )

        let sut = BillOccurrenceProvider()
        let occurrences = await sut.unpaidOccurrences(
            from: [bill],
            referenceDate: referenceDate,
            horizonDays: 365,
            calendar: calendar
        )

        let latest = occurrences.map(\.dueDate).max()
        #expect(latest != nil)
        if let latest {
            #expect(latest <= endDate, "Expected no occurrences after endDate")
        }
    }

    @Test
    func whenMultipleBills_thenOccurrencesAreSortedByDueDate() async throws {
        let early = try makeBill(dueDate: makeDate(day: 5), recurrence: nil)
        let late = try makeBill(dueDate: makeDate(day: 10), recurrence: nil)

        let sut = BillOccurrenceProvider()
        let occurrences = await sut.unpaidOccurrences(
            from: [late, early],
            referenceDate: makeDate(day: 3),
            horizonDays: 90,
            calendar: calendar
        )

        let dates = occurrences.map(\.dueDate)
        #expect(dates == dates.sorted(), "Occurrences should be sorted by dueDate")
    }

    // MARK: - Helpers

    private func makeBill(
        dueDate: Date,
        recurrence: RepeatIntervalType?
    ) throws -> Bill {
        let schema = Schema([Bill.self, PaymentEntry.self, IssuedOccurrence.self, RecurrenceRule.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let rule = recurrence.map { RecurrenceRule(pattern: $0, frequency: 1) }
        let bill = Bill(
            name: "Test Bill",
            amount: 100,
            dueDate: dueDate,
            recurrenceRule: rule
        )

        context.insert(bill)
        try context.save()

        return bill
    }

    private func makeBillWithContext(
        dueDate: Date,
        recurrence: RepeatIntervalType?
    ) throws -> (bill: Bill, context: ModelContext) {
        let schema = Schema([Bill.self, PaymentEntry.self, IssuedOccurrence.self, RecurrenceRule.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let rule = recurrence.map { RecurrenceRule(pattern: $0, frequency: 1) }
        let bill = Bill(
            name: "Test Bill",
            amount: 100,
            dueDate: dueDate,
            recurrenceRule: rule
        )

        context.insert(bill)
        try context.save()

        return (bill, context)
    }

    private func makeBillWithContext(
        dueDate: Date,
        recurrence: RepeatIntervalType?,
        endDate: Date
    ) throws -> (bill: Bill, context: ModelContext) {
        let schema = Schema([Bill.self, PaymentEntry.self, IssuedOccurrence.self, RecurrenceRule.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let rule = recurrence.map {
            RecurrenceRule(
                pattern: $0,
                frequency: 1,
                endConditionType: .endDate,
                endDate: endDate
            )
        }

        let bill = Bill(
            name: "Test Bill",
            amount: 100,
            dueDate: dueDate,
            recurrenceRule: rule
        )

        context.insert(bill)
        try context.save()

        return (bill, context)
    }

    private func makeDate(year: Int = 2025, month: Int = 12, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
