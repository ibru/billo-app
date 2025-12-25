//  Created by Jiri Urbasek on 12/25/25.

import Testing
import Foundation
@testable import Billo

@Suite("CalendarMonthComparison")
@MainActor
struct CalendarMonthComparisonTests {
    @Test func whenDisplayedMonthIsCurrentMonth_thenReturnsTrue() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let referenceDate = makeDate(year: 2025, month: 12, day: 25, calendar: calendar)
        let displayed = calendar.dateComponents([.year, .month], from: referenceDate)

        let result = CalendarMonthComparison.isSameMonth(displayed, as: referenceDate, calendar: calendar)

        #expect(result == true)
    }

    @Test func whenDisplayedMonthIsDifferentMonth_thenReturnsFalse() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let referenceDate = makeDate(year: 2025, month: 12, day: 25, calendar: calendar)
        let displayed = DateComponents(year: 2025, month: 11)

        let result = CalendarMonthComparison.isSameMonth(displayed, as: referenceDate, calendar: calendar)

        #expect(result == false)
    }

    @Test func whenDisplayedMonthIsInvalid_thenReturnsTrueToAvoidShowingToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let referenceDate = makeDate(year: 2025, month: 12, day: 25, calendar: calendar)
        let invalid = DateComponents()

        let result = CalendarMonthComparison.isSameMonth(invalid, as: referenceDate, calendar: calendar)

        #expect(result == true)
    }
}

private func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day))!
}
