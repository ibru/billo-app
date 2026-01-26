//  Created by Jiri Urbasek on 01/26/26.

import Testing
import Foundation
@testable import Billo

@Suite("DateAnchorSynchronizer") @MainActor
struct DateAnchorSynchronizerTests {

    // MARK: - weekday(from:)

    @Suite("weekday(from:)") @MainActor
    struct WeekdayFromDate {
        @Test func whenDateIsMonday_thenReturnsMonday() {
            let sut = makeSUT()
            let monday = makeDate(year: 2025, month: 1, day: 6) // Monday

            let result = sut.weekday(from: monday)

            #expect(result == .monday)
        }

        @Test func whenDateIsFriday_thenReturnsFriday() {
            let sut = makeSUT()
            let friday = makeDate(year: 2025, month: 1, day: 10) // Friday

            let result = sut.weekday(from: friday)

            #expect(result == .friday)
        }

        @Test func whenDateIsSunday_thenReturnsSunday() {
            let sut = makeSUT()
            let sunday = makeDate(year: 2025, month: 1, day: 5) // Sunday

            let result = sut.weekday(from: sunday)

            #expect(result == .sunday)
        }
    }

    // MARK: - dayOfMonth(from:)

    @Suite("dayOfMonth(from:)") @MainActor
    struct DayOfMonthFromDate {
        @Test func whenDateIs15th_thenReturns15() {
            let sut = makeSUT()
            let date = makeDate(year: 2025, month: 1, day: 15)

            let result = sut.dayOfMonth(from: date)

            #expect(result == 15)
        }

        @Test func whenDateIs1st_thenReturns1() {
            let sut = makeSUT()
            let date = makeDate(year: 2025, month: 1, day: 1)

            let result = sut.dayOfMonth(from: date)

            #expect(result == 1)
        }

        @Test func whenDateIs31st_thenReturns31() {
            let sut = makeSUT()
            let date = makeDate(year: 2025, month: 1, day: 31)

            let result = sut.dayOfMonth(from: date)

            #expect(result == 31)
        }
    }

    // MARK: - syncDateToWeekday(_:weekday:)

    @Suite("syncDateToWeekday") @MainActor
    struct SyncDateToWeekday {
        @Test func whenAlreadyOnTargetWeekday_thenReturnsNil() {
            let sut = makeSUT()
            let monday = makeDate(year: 2025, month: 1, day: 6) // Monday

            let result = sut.syncDateToWeekday(monday, weekday: .monday)

            #expect(result == nil)
        }

        @Test func whenTargetWeekdayIsAhead_thenSnapsForward() {
            let sut = makeSUT()
            let monday = makeDate(year: 2025, month: 1, day: 6) // Monday

            let result = sut.syncDateToWeekday(monday, weekday: .wednesday)

            #expect(result == makeDate(year: 2025, month: 1, day: 8)) // Wednesday
        }

        @Test func whenTargetWeekdayIsBehind_thenSnapsForwardToNextWeek() {
            let sut = makeSUT()
            let wednesday = makeDate(year: 2025, month: 1, day: 8) // Wednesday

            let result = sut.syncDateToWeekday(wednesday, weekday: .monday)

            #expect(result == makeDate(year: 2025, month: 1, day: 13)) // Next Monday
        }

        @Test func whenFridayToMonday_thenSnapsToNextMonday() {
            let sut = makeSUT()
            let friday = makeDate(year: 2025, month: 1, day: 10) // Friday

            let result = sut.syncDateToWeekday(friday, weekday: .monday)

            #expect(result == makeDate(year: 2025, month: 1, day: 13)) // Monday
        }

        @Test func whenSundayToSaturday_thenSnapsToNextSaturday() {
            let sut = makeSUT()
            let sunday = makeDate(year: 2025, month: 1, day: 5) // Sunday

            let result = sut.syncDateToWeekday(sunday, weekday: .saturday)

            #expect(result == makeDate(year: 2025, month: 1, day: 11)) // Saturday
        }

        @Test func whenMondayToSunday_thenSnapsToSameSunday() {
            let sut = makeSUT()
            let monday = makeDate(year: 2025, month: 1, day: 6) // Monday

            let result = sut.syncDateToWeekday(monday, weekday: .sunday)

            #expect(result == makeDate(year: 2025, month: 1, day: 12)) // Next Sunday
        }
    }

    // MARK: - syncDateToDayOfMonth(_:targetDay:)

    @Suite("syncDateToDayOfMonth") @MainActor
    struct SyncDateToDayOfMonth {
        @Test func whenAlreadyOnTargetDay_thenReturnsNil() {
            let sut = makeSUT()
            let date = makeDate(year: 2025, month: 1, day: 15)

            let result = sut.syncDateToDayOfMonth(date, targetDay: 15)

            #expect(result == nil)
        }

        @Test func whenTargetDayIsAhead_thenReturnsDateWithTargetDay() {
            let sut = makeSUT()
            let date = makeDate(year: 2025, month: 1, day: 10)

            let result = sut.syncDateToDayOfMonth(date, targetDay: 20)

            #expect(result == makeDate(year: 2025, month: 1, day: 20))
        }

        @Test func whenTargetDayIsBehind_thenMovesToNextMonth() {
            let sut = makeSUT()
            let date = makeDate(year: 2025, month: 1, day: 20)

            let result = sut.syncDateToDayOfMonth(date, targetDay: 10)

            #expect(result == makeDate(year: 2025, month: 2, day: 10))
        }

        @Test func whenTargetDayIs31AndNextMonthHas28Days_thenAdjustsTo28() {
            let sut = makeSUT()
            let date = makeDate(year: 2025, month: 1, day: 31) // Jan 31

            let result = sut.syncDateToDayOfMonth(date, targetDay: 15)

            // Target day 15 is behind current day 31, so move to Feb 15
            #expect(result == makeDate(year: 2025, month: 2, day: 15))
        }

        @Test func whenTargetDayIs31InFebruary_thenAdjustsToLastDayOfMonth() {
            let sut = makeSUT()
            let date = makeDate(year: 2025, month: 2, day: 15) // Feb 15

            let result = sut.syncDateToDayOfMonth(date, targetDay: 31)

            // Feb 2025 has 28 days, so target 31 becomes 28
            #expect(result == makeDate(year: 2025, month: 2, day: 28))
        }

        @Test func whenTargetDayIs31MovingFromJan15ToNextMonth_thenAdjustsToFeb28() {
            let sut = makeSUT()
            let date = makeDate(year: 2025, month: 1, day: 15) // Jan 15

            let result = sut.syncDateToDayOfMonth(date, targetDay: 31)

            // Target 31 is ahead, so Jan 31
            #expect(result == makeDate(year: 2025, month: 1, day: 31))
        }

        @Test func whenCrossingYearBoundary_thenMovesToNextYear() {
            let sut = makeSUT()
            let date = makeDate(year: 2025, month: 12, day: 20) // Dec 20

            let result = sut.syncDateToDayOfMonth(date, targetDay: 5)

            // Target day 5 is behind, move to Jan 5 next year
            #expect(result == makeDate(year: 2026, month: 1, day: 5))
        }

        @Test func whenTargetDayIs1AndCurrentIs31_thenMovesToNextMonth() {
            let sut = makeSUT()
            let date = makeDate(year: 2025, month: 1, day: 31) // Jan 31

            let result = sut.syncDateToDayOfMonth(date, targetDay: 1)

            #expect(result == makeDate(year: 2025, month: 2, day: 1))
        }

        @Test func whenLeapYearFeb29_thenHandlesCorrectly() {
            let sut = makeSUT()
            let date = makeDate(year: 2024, month: 2, day: 15) // Feb 15, 2024 (leap year)

            let result = sut.syncDateToDayOfMonth(date, targetDay: 29)

            // 2024 is a leap year, Feb has 29 days
            #expect(result == makeDate(year: 2024, month: 2, day: 29))
        }
    }
}

// MARK: - Test Helpers

@MainActor
private func makeSUT() -> DateAnchorSynchronizer {
    DateAnchorSynchronizer(calendar: makeUTCCalendar())
}

private func makeDate(year: Int, month: Int, day: Int) -> Date {
    let calendar = makeUTCCalendar()
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return calendar.date(from: components)!
}

private func makeUTCCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.locale = Locale(identifier: "en_US")
    return calendar
}
