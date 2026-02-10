//  Created by Jiri Urbasek on 12/02/25.

import Testing
import Foundation
@testable import Billo

@Suite("BadgeCalculator")
@MainActor
struct BadgeCalculatorTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.locale = Locale(identifier: "en_US")
        return cal
    }()

    @Test
    func whenModeNever_thenReturnsZero() {
        let calc = BadgeCalculator(calendar: calendar, baseHorizonDays: 90)
        let result = calc.calculateBadgeCount(
            bills: [],
            badgeMode: .never,
            referenceDate: Date()
        )
        #expect(result == 0)
    }

    @Test
    func whenModeDueAndOverdue_thenCountsOnlyDueAndOverdue() {
        let calc = BadgeCalculator(calendar: calendar, baseHorizonDays: 90)
        let reference = makeDate(2025, 12, 10)
        let overdue = makeOccurrence(due: makeDate(2025, 12, 8))
        let dueToday = makeOccurrence(due: makeDate(2025, 12, 10))
        let future = makeOccurrence(due: makeDate(2025, 12, 12))

        let count = calc.calculateBadgeCount(
            bills: [overdue.bill, dueToday.bill, future.bill],
            badgeMode: .dueAndOverdue,
            referenceDate: reference
        )

        #expect(count == 2)
    }

    @Test
    func whenModeDaysBeforeThree_thenIncludesOverdueDueAndWithinWindow() {
        let calc = BadgeCalculator(calendar: calendar, baseHorizonDays: 90)
        let reference = makeDate(2025, 12, 10)
        let overdue = makeOccurrence(due: makeDate(2025, 12, 8))
        let within1 = makeOccurrence(due: makeDate(2025, 12, 11))
        let within3 = makeOccurrence(due: makeDate(2025, 12, 13))
        let outside = makeOccurrence(due: makeDate(2025, 12, 15))

        let count = calc.calculateBadgeCount(
            bills: [overdue.bill, within1.bill, within3.bill, outside.bill],
            badgeMode: .daysBefore(3),
            referenceDate: reference
        )

        #expect(count == 3)
    }

    @Test
    func whenModeDueAndOverdueAndDueTodayWithNonMidnightTime_thenIncludesOccurrence() {
        let calc = BadgeCalculator(calendar: calendar, baseHorizonDays: 90)
        let reference = makeDate(2025, 12, 10, hour: 14, minute: 0)
        // Due date is same day but with a morning time component (simulates pre-migration data)
        let dueTodayMorning = makeOccurrence(due: makeDate(2025, 12, 10, hour: 9, minute: 0))

        let count = calc.calculateBadgeCount(
            occurrences: [dueTodayMorning],
            badgeMode: .dueAndOverdue,
            referenceDate: reference
        )

        #expect(count == 1)
    }

    @Test
    func whenModeDaysBeforeZeroAndDueDateIsTomorrowWithEarlierClockTime_thenExcludesOccurrence() {
        let calc = BadgeCalculator(calendar: calendar, baseHorizonDays: 90)
        let reference = makeDate(2025, 12, 10, hour: 23, minute: 0)
        let tomorrowEarly = makeOccurrence(due: makeDate(2025, 12, 11, hour: 1, minute: 0))

        let count = calc.calculateBadgeCount(
            occurrences: [tomorrowEarly],
            badgeMode: .daysBefore(0),
            referenceDate: reference
        )

        #expect(count == 0)
    }

    @Test
    func whenRecurringBillNotDueToday_thenBadgeCountExcludesToday() {
        // Given: Monthly bill due on 20th, today is 3rd
        let calc = BadgeCalculator(calendar: calendar, baseHorizonDays: 90)
        let reference = makeDate(2025, 12, 3)  // Today is the 3rd

        let bill = makeBillWithRecurrence(
            dueDate: makeDate(2025, 12, 20),  // Due on 20th
            pattern: .monthly
        )

        // When: Calculate badge count for "due and overdue"
        let count = calc.calculateBadgeCount(
            bills: [bill],
            badgeMode: .dueAndOverdue,
            referenceDate: reference
        )

        // Then: Should NOT count a fake "today" occurrence
        #expect(count == 0, "Should not count fake 'today' occurrence for bill due on 20th")
    }

    // MARK: - Helpers

    private func makeDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func makeDate(_ y: Int, _ m: Int, _ d: Int, hour: Int, minute: Int) -> Date {
        calendar.date(
            from: DateComponents(
                year: y,
                month: m,
                day: d,
                hour: hour,
                minute: minute
            )
        )!
    }

    private func makeOccurrence(due: Date) -> BillOccurrence {
        let bill = Bill(name: "Test", amount: 10, currencyCode: "USD", dueDate: due)
        return BillOccurrence(bill: bill, dueDate: due)
    }

    private func makeBillWithRecurrence(dueDate: Date, pattern: RepeatIntervalType) -> Bill {
        let rule = RecurrenceRule(pattern: pattern, frequency: 1)
        return Bill(
            name: "Test Recurring",
            amount: 100,
            currencyCode: "USD",
            dueDate: dueDate,
            recurrenceRule: rule
        )
    }
}
