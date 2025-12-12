//  Created by Jiri Urbasek on 12/02/25.

import Testing
import Foundation
@testable import Billo

@Suite("NotificationDateCalculator")
@MainActor
struct NotificationDateCalculatorTests {
    let sut = NotificationDateCalculator()
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.locale = Locale(identifier: "en_US")
        return cal
    }()

    // MARK: - notificationDate

    @Suite("notificationDate")
    @MainActor
    struct NotificationDate {
        let sut = NotificationDateCalculator()
        let calendar: Calendar = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            cal.locale = Locale(identifier: "en_US")
            return cal
        }()

        @Test
        func whenOffsetIs3DaysAndTimeIs9AM_thenReturnsCorrectDate() {
            // Given: Bill due Dec 10, reminder time 9:00 AM, offset 3 days
            // Reference date: Dec 1 at 8:00 AM
            let dueDate = makeDate(2025, 12, 10, hour: 0, minute: 0)
            let referenceDate = makeDate(2025, 12, 1, hour: 8, minute: 0)
            let time = DateComponents(hour: 9, minute: 0)

            // When: Calculate notification date with 3-day offset
            let result = sut.notificationDate(
                for: dueDate,
                offsetDays: 3,
                time: time,
                referenceDate: referenceDate,
                calendar: calendar
            )

            // Then: Should schedule for Dec 7 at 9:00 AM (3 days before Dec 10)
            let expected = makeDate(2025, 12, 7, hour: 9, minute: 0)
            #expect(result == expected)
        }

        @Test
        func whenDayOfAndTimeNotPassed_thenReturnsScheduledTime() {
            // Given: Bill due Dec 1, reminder time 9:00 AM, offset 0 (day-of)
            // Reference date: Dec 1 at 8:00 AM (before 9 AM)
            let dueDate = makeDate(2025, 12, 1, hour: 0, minute: 0)
            let referenceDate = makeDate(2025, 12, 1, hour: 8, minute: 0)
            let time = DateComponents(hour: 9, minute: 0)

            // When: Calculate notification date for day-of
            let result = sut.notificationDate(
                for: dueDate,
                offsetDays: 0,
                time: time,
                referenceDate: referenceDate,
                calendar: calendar
            )

            // Then: Should schedule for Dec 1 at 9:00 AM
            let expected = makeDate(2025, 12, 1, hour: 9, minute: 0)
            #expect(result == expected)
        }

        @Test
        func whenDayOfAndTimeHasPassed_thenReturnsNil() {
            // Given: Bill due Dec 1, reminder time 9:00 AM, offset 0 (day-of)
            // Reference date: Dec 1 at 10:30 AM (after 9 AM)
            let dueDate = makeDate(2025, 12, 1, hour: 0, minute: 0)
            let referenceDate = makeDate(2025, 12, 1, hour: 10, minute: 30)
            let time = DateComponents(hour: 9, minute: 0)

            // When: Calculate notification date for day-of (time passed)
            let result = sut.notificationDate(
                for: dueDate,
                offsetDays: 0,
                time: time,
                referenceDate: referenceDate,
                calendar: calendar
            )

            // Then: Should return nil (too late to notify)
            #expect(result == nil)
        }

        @Test
        func whenOffset3DaysAndSameDayButTimeHasPassed_thenReturnsNil() {
            // Given: Bill due Dec 10, reminder time 9:00 AM, offset 3 days
            // Reference date: Dec 7 at 4:00 PM (target day, but time has passed)
            let dueDate = makeDate(2025, 12, 10, hour: 0, minute: 0)
            let referenceDate = makeDate(2025, 12, 7, hour: 16, minute: 0)
            let time = DateComponents(hour: 9, minute: 0)

            // When: Calculate notification date (same day, time passed)
            let result = sut.notificationDate(
                for: dueDate,
                offsetDays: 3,
                time: time,
                referenceDate: referenceDate,
                calendar: calendar
            )

            // Then: Should return nil (too late to notify)
            #expect(result == nil)
        }

        @Test
        func whenTargetDayHasPassedEntirely_thenReturnsNil() {
            // Given: Bill due Dec 1, reminder time 9:00 AM, offset 3 days
            // Reference date: Dec 5 at 8:00 AM (target day Nov 28 has passed)
            let dueDate = makeDate(2025, 12, 1, hour: 0, minute: 0)
            let referenceDate = makeDate(2025, 12, 5, hour: 8, minute: 0)
            let time = DateComponents(hour: 9, minute: 0)

            // When: Calculate notification date (target day passed)
            let result = sut.notificationDate(
                for: dueDate,
                offsetDays: 3,
                time: time,
                referenceDate: referenceDate,
                calendar: calendar
            )

            // Then: Should return nil (too late to notify)
            #expect(result == nil)
        }

        @Test
        func whenOffset7Days_thenReturnsCorrectDate() {
            // Given: Bill due Dec 15, reminder time 14:30, offset 7 days
            let dueDate = makeDate(2025, 12, 15, hour: 0, minute: 0)
            let referenceDate = makeDate(2025, 12, 1, hour: 8, minute: 0)
            let time = DateComponents(hour: 14, minute: 30)

            // When: Calculate notification date
            let result = sut.notificationDate(
                for: dueDate,
                offsetDays: 7,
                time: time,
                referenceDate: referenceDate,
                calendar: calendar
            )

            // Then: Should schedule for Dec 8 at 14:30
            let expected = makeDate(2025, 12, 8, hour: 14, minute: 30)
            #expect(result == expected)
        }

        @Test
        func whenOffsetIs5Days_thenReturnsCorrectDate() {
            // Given: Bill due Dec 20, reminder time 9:00 AM, offset 5 days
            let dueDate = makeDate(2025, 12, 20, hour: 0, minute: 0)
            let referenceDate = makeDate(2025, 12, 10, hour: 8, minute: 0)
            let time = DateComponents(hour: 9, minute: 0)

            // When: Calculate notification date
            let result = sut.notificationDate(
                for: dueDate,
                offsetDays: 5,
                time: time,
                referenceDate: referenceDate,
                calendar: calendar
            )

            // Then: Should schedule for Dec 15 at 9:00 AM
            let expected = makeDate(2025, 12, 15, hour: 9, minute: 0)
            #expect(result == expected)
        }

        // MARK: - Helpers

        private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int, minute: Int) -> Date {
            let components = DateComponents(
                calendar: calendar,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
            return calendar.date(from: components)!
        }
    }

    @Suite("occurrencesWithinLookahead")
    @MainActor
    struct OccurrencesWithinLookahead {
        let sut = NotificationDateCalculator()
        let calendar: Calendar = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            cal.locale = Locale(identifier: "en_US")
            return cal
        }()

        @Test
        func whenOccurrencesWithinWindow_thenReturnsFiltered() {
            // Given: Reference date Dec 1, lookahead 5 days
            let referenceDate = makeDate(2025, 12, 1)
            let occurrences = [
                makeOccurrence(dueDate: makeDate(2025, 12, 2)),  // +1 day: include
                makeOccurrence(dueDate: makeDate(2025, 12, 5)),  // +4 days: include
                makeOccurrence(dueDate: makeDate(2025, 12, 6)),  // +5 days: include
                makeOccurrence(dueDate: makeDate(2025, 12, 7)),  // +6 days: exclude
                makeOccurrence(dueDate: makeDate(2025, 11, 30)), // -1 day: exclude
            ]

            // When: Filter by lookahead window
            let result = sut.occurrencesWithinLookahead(
                occurrences,
                lookaheadDays: 5,
                referenceDate: referenceDate,
                calendar: calendar
            )

            // Then: Should return 3 occurrences within 5 days
            #expect(result.count == 3)
            #expect(result.map(\.dueDate) == [
                makeDate(2025, 12, 2),
                makeDate(2025, 12, 5),
                makeDate(2025, 12, 6)
            ])
        }

        @Test
        func whenNoOccurrencesWithinWindow_thenReturnsEmpty() {
            let referenceDate = makeDate(2025, 12, 1)
            let occurrences = [
                makeOccurrence(dueDate: makeDate(2025, 12, 10)),
                makeOccurrence(dueDate: makeDate(2025, 12, 20)),
            ]

            let result = sut.occurrencesWithinLookahead(
                occurrences,
                lookaheadDays: 5,
                referenceDate: referenceDate,
                calendar: calendar
            )

            #expect(result.isEmpty)
        }

        @Test
        func whenEmptyOccurrences_thenReturnsEmpty() {
            let result = sut.occurrencesWithinLookahead(
                [],
                lookaheadDays: 5,
                referenceDate: makeDate(2025, 12, 1),
                calendar: calendar
            )

            #expect(result.isEmpty)
        }

        // MARK: - Helpers

        private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
            let components = DateComponents(year: year, month: month, day: day)
            return calendar.date(from: components)!
        }

        private func makeOccurrence(dueDate: Date) -> BillOccurrence {
            makeTestOccurrence(dueDate: dueDate)
        }
    }

    @Suite("schedulingPlan")
    @MainActor
    struct SchedulingPlan {
        let sut = NotificationDateCalculator()
        let calendar: Calendar = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            cal.locale = Locale(identifier: "en_US")
            return cal
        }()

        @Test
        func whenOccurrencesFitInCap_thenAllScheduledAndZeroSkipped() {
            // Given: 10 occurrences × 4 offsets = 40 notifications, cap 60
            let occurrences = makeOccurrences(count: 10)
            let offsets = [0, 3, 5, 7]

            // When: Calculate scheduling plan
            let (schedulable, skipped) = sut.schedulingPlan(
                occurrences: occurrences,
                offsets: offsets,
                maxSlots: 60
            )

            // Then: All 40 should fit
            #expect(schedulable.count == 40)
            #expect(skipped == 0)
        }

        @Test
        func whenOccurrencesExceedCap_thenSkippedCountIsCorrect() {
            // Given: 20 occurrences × 4 offsets = 80 notifications, cap 60
            let occurrences = makeOccurrences(count: 20)
            let offsets = [0, 3, 5, 7]

            // When: Calculate scheduling plan
            let (schedulable, skipped) = sut.schedulingPlan(
                occurrences: occurrences,
                offsets: offsets,
                maxSlots: 60
            )

            // Then: 60 scheduled, 20 skipped
            #expect(schedulable.count == 60)
            #expect(skipped == 20)
        }

        @Test
        func whenCapIsZero_thenAllSkipped() {
            let occurrences = makeOccurrences(count: 5)
            let offsets = [0, 3]

            let (schedulable, skipped) = sut.schedulingPlan(
                occurrences: occurrences,
                offsets: offsets,
                maxSlots: 0
            )

            #expect(schedulable.isEmpty)
            #expect(skipped == 10) // 5 × 2
        }

        @Test
        func whenPrioritizeSoonest_thenSchedulesInOrder() {
            let occurrences = makeOccurrences(count: 3)
            let offsets = [0, 3]

            let (schedulable, _) = sut.schedulingPlan(
                occurrences: occurrences,
                offsets: offsets,
                maxSlots: 100
            )

            // Should schedule all offsets for occurrence 0, then occurrence 1, etc.
            #expect(schedulable[0].0.id == occurrences[0].id)
            #expect(schedulable[0].1 == 0)
            #expect(schedulable[1].0.id == occurrences[0].id)
            #expect(schedulable[1].1 == 3)
            #expect(schedulable[2].0.id == occurrences[1].id)
            #expect(schedulable[2].1 == 0)
        }

        // MARK: - Helpers

        private func makeOccurrences(count: Int) -> [BillOccurrence] {
            (0..<count).map { index in
                let dueDate = calendar.date(byAdding: .day, value: index, to: Date())!
                return makeTestOccurrence(dueDate: dueDate)
            }
        }
    }
}

// MARK: - Test Helpers

/// Creates a test BillOccurrence for pure logic testing
@MainActor
private func makeTestOccurrence(dueDate: Date) -> BillOccurrence {
    let bill = Bill(
        name: "Test Bill",
        amount: 100.0,
        currencyCode: "USD",
        dueDate: dueDate
    )
    return BillOccurrence(bill: bill, dueDate: dueDate)
}
