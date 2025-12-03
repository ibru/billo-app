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
    func WHEN_monthlyBillDueOn20th_AND_todayIs3rd_THEN_noTodayOccurrenceGenerated() async throws {
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
        if let first = occurrences.first {
            let day = calendar.component(.day, from: first.dueDate)
            #expect(day == 20, "First occurrence should be on the 20th, got \(day)")
        }
    }

    @Test
    func WHEN_oneTimeBillDueOn10th_AND_todayIs3rd_THEN_occurrenceIs10th() async throws {
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
        if let occurrence = occurrences.first {
            let day = calendar.component(.day, from: occurrence.dueDate)
            #expect(day == 10, "Occurrence should be on the 10th, got \(day)")
        }
    }

    @Test
    func WHEN_weeklyBillDueOnMonday_AND_todayIsFriday_THEN_noTodayOccurrenceGenerated() async throws {
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
    func WHEN_billIsDueToday_THEN_todayOccurrenceIsIncluded() async throws {
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
        if let todayOccurrence = occurrences.first(where: { calendar.isDate($0.dueDate, inSameDayAs: referenceDate) }) {
            let day = calendar.component(.day, from: todayOccurrence.dueDate)
            #expect(day == 10, "Today's occurrence should be on the 10th")
        }
    }

    @Test
    func WHEN_billIsOverdue_THEN_overdueOccurrenceIsIncluded() async throws {
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
    func WHEN_dailyBillNotDueToday_THEN_noFakeTodayOccurrence() async throws {
        // Given: Daily bill starting on the 1st, today is the 3rd
        let bill = try makeBill(
            dueDate: makeDate(year: 2025, month: 12, day: 1),
            recurrence: .daily
        )
        let referenceDate = makeDate(year: 2025, month: 12, day: 3)

        // When: Generate unpaid occurrences
        let sut = BillOccurrenceProvider()
        let occurrences = await sut.unpaidOccurrences(
            from: [bill],
            referenceDate: referenceDate,
            horizonDays: 7,  // Just check next week
            calendar: calendar
        )

        // Then: Should include occurrences on 1st, 2nd, 3rd, 4th, 5th, 6th, 7th, 8th, 9th, 10th
        // But the key test: each date should be exactly once (no duplicates of "today")
        let uniqueDates = Set(occurrences.map { calendar.startOfDay(for: $0.dueDate) })
        #expect(uniqueDates.count == occurrences.count, "Should not have duplicate occurrences for the same day")

        // And: Should include the 3rd (today) as one of the occurrences
        let hasToday = occurrences.contains { occ in
            calendar.isDate(occ.dueDate, inSameDayAs: referenceDate)
        }
        #expect(hasToday, "Daily bill should include today's occurrence")
    }

    @Test
    func WHEN_billHasYearsOfHistory_THEN_onlyRecentOccurrencesIncluded() async throws {
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

    // MARK: - Helpers

    private func makeBill(
        dueDate: Date,
        recurrence: RepeatIntervalType?
    ) throws -> Bill {
        let schema = Schema([Bill.self, Payment.self, RecurrenceRule.self])
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

    private func makeDate(year: Int = 2025, month: Int = 12, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
