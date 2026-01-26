//  Created by Jiri Urbasek on 11/26/25.

import Testing
import Foundation
@testable import Billo

@Suite("RecurrenceRule") @MainActor
struct RecurrenceRuleTests {

    @Suite("generateOccurrences - Weekly") @MainActor
    struct WeeklyRecurrence {
        @Test func whenWeekly_thenGeneratesOccurrencesEveryWeek() {
            let (sut, startDate, endDate, calendar) = makeSUT(pattern: .weekly, frequency: 1)

            let occurrences = sut.generateOccurrences(from: startDate, until: endDate, calendar: calendar)

            #expect(occurrences.count == 3)
            #expect(occurrences[0] == makeDate(day: 1))
            #expect(occurrences[1] == makeDate(day: 8))
            #expect(occurrences[2] == makeDate(day: 15))
        }

        @Test func whenWeeklyWithFrequencyTwo_thenGeneratesOccurrencesEveryTwoWeeks() {
            let (sut, startDate, endDate, calendar) = makeSUT(pattern: .weekly, frequency: 2)

            let occurrences = sut.generateOccurrences(from: startDate, until: endDate, calendar: calendar)

            #expect(occurrences.count == 2)
            #expect(occurrences[0] == makeDate(day: 1))
            #expect(occurrences[1] == makeDate(day: 15))
        }

        @Test func whenWeeklyWithDayOfWeekSameAsAnchor_thenStartsOnAnchorDate() {
            // Jan 6, 2025 is a Monday
            let startDate = makeDate(year: 2025, month: 1, day: 6)
            let endDate = makeDate(year: 2025, month: 1, day: 27)
            let sut = RecurrenceRule(pattern: .weekly, frequency: 1, dayOfWeek: .monday)

            let occurrences = sut.generateOccurrences(from: startDate, until: endDate, calendar: makeUTCCalendar())

            #expect(occurrences.count == 4)
            #expect(occurrences[0] == startDate) // Mon Jan 6
            #expect(occurrences[1] == makeDate(year: 2025, month: 1, day: 13)) // Mon Jan 13
            #expect(occurrences[2] == makeDate(year: 2025, month: 1, day: 20)) // Mon Jan 20
            #expect(occurrences[3] == makeDate(year: 2025, month: 1, day: 27)) // Mon Jan 27
        }

        @Test func whenWeeklyWithDayOfWeekDifferentFromAnchor_thenSnapsForwardToTargetWeekday() {
            // Jan 8, 2025 is a Wednesday, but we want Monday
            let startDate = makeDate(year: 2025, month: 1, day: 8) // Wednesday
            let endDate = makeDate(year: 2025, month: 2, day: 3)
            let sut = RecurrenceRule(pattern: .weekly, frequency: 1, dayOfWeek: .monday)

            let occurrences = sut.generateOccurrences(from: startDate, until: endDate, calendar: makeUTCCalendar())

            // Should snap forward from Wed Jan 8 to Mon Jan 13, then every Monday
            #expect(occurrences.count == 4)
            #expect(occurrences[0] == makeDate(year: 2025, month: 1, day: 13)) // Mon Jan 13
            #expect(occurrences[1] == makeDate(year: 2025, month: 1, day: 20)) // Mon Jan 20
            #expect(occurrences[2] == makeDate(year: 2025, month: 1, day: 27)) // Mon Jan 27
            #expect(occurrences[3] == makeDate(year: 2025, month: 2, day: 3))  // Mon Feb 3
        }

        @Test func whenBiweeklyWithDayOfWeekDifferentFromAnchor_thenSnapsAndRepeatsEveryTwoWeeks() {
            // Jan 8, 2025 is a Wednesday, but we want Friday
            let startDate = makeDate(year: 2025, month: 1, day: 8) // Wednesday
            let endDate = makeDate(year: 2025, month: 2, day: 28)
            let sut = RecurrenceRule(pattern: .weekly, frequency: 2, dayOfWeek: .friday)

            let occurrences = sut.generateOccurrences(from: startDate, until: endDate, calendar: makeUTCCalendar())

            // Should snap forward from Wed Jan 8 to Fri Jan 10, then every 2 weeks
            #expect(occurrences.count == 4)
            #expect(occurrences[0] == makeDate(year: 2025, month: 1, day: 10)) // Fri Jan 10
            #expect(occurrences[1] == makeDate(year: 2025, month: 1, day: 24)) // Fri Jan 24
            #expect(occurrences[2] == makeDate(year: 2025, month: 2, day: 7))  // Fri Feb 7
            #expect(occurrences[3] == makeDate(year: 2025, month: 2, day: 21)) // Fri Feb 21
        }

        @Test func whenWeeklyWithDayOfWeekBackwardFromAnchor_thenSnapsForwardToNextWeek() {
            // Jan 10, 2025 is a Friday, but we want Monday (which already passed this week)
            let startDate = makeDate(year: 2025, month: 1, day: 10) // Friday
            let endDate = makeDate(year: 2025, month: 2, day: 3)
            let sut = RecurrenceRule(pattern: .weekly, frequency: 1, dayOfWeek: .monday)

            let occurrences = sut.generateOccurrences(from: startDate, until: endDate, calendar: makeUTCCalendar())

            // Should snap forward from Fri Jan 10 to Mon Jan 13 (next Monday)
            #expect(occurrences.count == 4)
            #expect(occurrences[0] == makeDate(year: 2025, month: 1, day: 13)) // Mon Jan 13
            #expect(occurrences[1] == makeDate(year: 2025, month: 1, day: 20)) // Mon Jan 20
            #expect(occurrences[2] == makeDate(year: 2025, month: 1, day: 27)) // Mon Jan 27
            #expect(occurrences[3] == makeDate(year: 2025, month: 2, day: 3))  // Mon Feb 3
        }

        @Test func whenWeeklyWithoutDayOfWeek_thenUsesAnchorDateAsIs() {
            // Jan 8, 2025 is a Wednesday, no dayOfWeek specified
            let startDate = makeDate(year: 2025, month: 1, day: 8) // Wednesday
            let endDate = makeDate(year: 2025, month: 1, day: 29)
            let sut = RecurrenceRule(pattern: .weekly, frequency: 1, dayOfWeek: nil)

            let occurrences = sut.generateOccurrences(from: startDate, until: endDate, calendar: makeUTCCalendar())

            // Should use anchor date as-is, repeat every Wednesday
            #expect(occurrences.count == 4)
            #expect(occurrences[0] == makeDate(year: 2025, month: 1, day: 8))  // Wed Jan 8
            #expect(occurrences[1] == makeDate(year: 2025, month: 1, day: 15)) // Wed Jan 15
            #expect(occurrences[2] == makeDate(year: 2025, month: 1, day: 22)) // Wed Jan 22
            #expect(occurrences[3] == makeDate(year: 2025, month: 1, day: 29)) // Wed Jan 29
        }
    }

    @Suite("snapToWeekday") @MainActor
    struct SnapToWeekday {
        @Test func whenAlreadyOnTargetWeekday_thenReturnsUnchanged() {
            // Jan 6, 2025 is a Monday
            let date = makeDate(year: 2025, month: 1, day: 6)

            let result = RecurrenceRuleGenerator.snapToWeekday(date, weekday: .monday, calendar: makeUTCCalendar())

            #expect(result == date)
        }

        @Test func whenTargetWeekdayIsAhead_thenSnapsForward() {
            // Jan 6, 2025 is Monday, target is Wednesday
            let date = makeDate(year: 2025, month: 1, day: 6)

            let result = RecurrenceRuleGenerator.snapToWeekday(date, weekday: .wednesday, calendar: makeUTCCalendar())

            #expect(result == makeDate(year: 2025, month: 1, day: 8)) // Wed Jan 8
        }

        @Test func whenTargetWeekdayIsBehind_thenSnapsForwardToNextWeek() {
            // Jan 8, 2025 is Wednesday, target is Monday
            let date = makeDate(year: 2025, month: 1, day: 8)

            let result = RecurrenceRuleGenerator.snapToWeekday(date, weekday: .monday, calendar: makeUTCCalendar())

            #expect(result == makeDate(year: 2025, month: 1, day: 13)) // Mon Jan 13
        }

        @Test func whenSunday_andTargetIsSaturday_thenSnapsToNextSaturday() {
            // Jan 5, 2025 is Sunday, target is Saturday
            let date = makeDate(year: 2025, month: 1, day: 5)

            let result = RecurrenceRuleGenerator.snapToWeekday(date, weekday: .saturday, calendar: makeUTCCalendar())

            #expect(result == makeDate(year: 2025, month: 1, day: 11)) // Sat Jan 11
        }
    }

    @Suite("generateOccurrences - Monthly") @MainActor
    struct MonthlyRecurrence {
        @Test func whenMonthly_thenGeneratesOccurrencesEveryMonth() {
            let calendar = makeUTCCalendar()
            let startDate = makeDate(year: 2025, month: 1, day: 15)
            let endDate = makeDate(year: 2025, month: 4, day: 1)
            let sut = RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 15)

            let occurrences = sut.generateOccurrences(from: startDate, until: endDate, calendar: calendar)

            #expect(occurrences.count == 3)
            #expect(occurrences[0] == makeDate(year: 2025, month: 1, day: 15))
            #expect(occurrences[1] == makeDate(year: 2025, month: 2, day: 15))
            #expect(occurrences[2] == makeDate(year: 2025, month: 3, day: 15))
        }

        @Test func whenMonthlyOn31st_thenAdjustsToLastDayOfMonthWithFewerDays() {
            let calendar = makeUTCCalendar()
            let startDate = makeDate(year: 2025, month: 1, day: 31)
            let endDate = makeDate(year: 2025, month: 4, day: 1)
            let sut = RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 31)

            let occurrences = sut.generateOccurrences(from: startDate, until: endDate, calendar: calendar)

            #expect(occurrences.count == 3)
            #expect(occurrences[0] == makeDate(year: 2025, month: 1, day: 31))
            #expect(occurrences[1] == makeDate(year: 2025, month: 2, day: 28))
            #expect(occurrences[2] == makeDate(year: 2025, month: 3, day: 31))
        }

        @Test func whenMonthlyWithFrequencyTwo_thenGeneratesOccurrencesEveryTwoMonths() {
            let calendar = makeUTCCalendar()
            let startDate = makeDate(year: 2025, month: 1, day: 15)
            let endDate = makeDate(year: 2025, month: 6, day: 1)
            let sut = RecurrenceRule(pattern: .monthly, frequency: 2, dayOfMonth: 15)

            let occurrences = sut.generateOccurrences(from: startDate, until: endDate, calendar: calendar)

            #expect(occurrences.count == 3)
            #expect(occurrences[0] == makeDate(year: 2025, month: 1, day: 15))
            #expect(occurrences[1] == makeDate(year: 2025, month: 3, day: 15))
            #expect(occurrences[2] == makeDate(year: 2025, month: 5, day: 15))
        }
    }

    @Suite("generateOccurrences - Yearly") @MainActor
    struct YearlyRecurrence {
        @Test func whenYearly_thenGeneratesOccurrencesEveryYear() {
            let calendar = makeUTCCalendar()
            let startDate = makeDate(year: 2025, month: 1, day: 15)
            let endDate = makeDate(year: 2028, month: 1, day: 1)
            let sut = RecurrenceRule(pattern: .yearly, frequency: 1)

            let occurrences = sut.generateOccurrences(from: startDate, until: endDate, calendar: calendar)

            #expect(occurrences.count == 3)
            #expect(occurrences[0] == makeDate(year: 2025, month: 1, day: 15))
            #expect(occurrences[1] == makeDate(year: 2026, month: 1, day: 15))
            #expect(occurrences[2] == makeDate(year: 2027, month: 1, day: 15))
        }
    }

    @Suite("generateOccurrences - End Conditions") @MainActor
    struct EndConditions {
        @Test func whenEndDateBeforeMaxDate_thenStopsAtEndDate() {
            let calendar = makeUTCCalendar()
            let startDate = makeDate(year: 2025, month: 1, day: 1)
            let endDate = makeDate(year: 2025, month: 1, day: 22)
            let maxDate = makeDate(year: 2025, month: 3, day: 30)
            let sut = RecurrenceRule(
                pattern: .weekly,
                frequency: 1,
                endConditionType: .endDate,
                endDate: endDate
            )

            let occurrences = sut.generateOccurrences(from: startDate, until: maxDate, calendar: calendar)

            // Jan 1, 8, 15, 22 = 4 weekly occurrences
            #expect(occurrences.count == 4)
            #expect(occurrences.last == endDate)
        }

        @Test func whenNeverEnds_thenStopsAtMaxDate() {
            let calendar = makeUTCCalendar()
            let startDate = makeDate(year: 2025, month: 1, day: 1)
            let maxDate = makeDate(year: 2025, month: 1, day: 22)
            let sut = RecurrenceRule(pattern: .weekly, frequency: 1, endConditionType: .never)

            let occurrences = sut.generateOccurrences(from: startDate, until: maxDate, calendar: calendar)

            // Jan 1, 8, 15, 22 = 4 weekly occurrences
            #expect(occurrences.count == 4)
            #expect(occurrences.last == maxDate)
        }
    }

    @Suite("matchingPreset")
    struct MatchingPreset {
        @Test func whenWeeklyFrequencyOneAndHasDayOfWeek_thenMatchesWeekly() {
            let sut = RecurrenceRule(pattern: .weekly, frequency: 1, dayOfWeek: .monday)

            #expect(sut.matchingPreset == .weekly)
        }

        @Test func whenWeeklyFrequencyTwoAndHasDayOfWeek_thenMatchesBiweekly() {
            let sut = RecurrenceRule(pattern: .weekly, frequency: 2, dayOfWeek: .monday)

            #expect(sut.matchingPreset == .biweekly)
        }

        @Test func whenMonthlyFrequencyOneAndHasDayOfMonth_thenMatchesMonthly() {
            let sut = RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 15)

            #expect(sut.matchingPreset == .monthly)
        }

        @Test func whenRuleDoesNotMatchPreset_thenMatchesCustom() {
            let sut = RecurrenceRule(pattern: .yearly, frequency: 1)

            #expect(sut.matchingPreset == .custom)
        }

        @Test func whenWeeklyWithoutDayOfWeek_thenMatchesCustom() {
            let sut = RecurrenceRule(pattern: .weekly, frequency: 1, dayOfWeek: nil)

            #expect(sut.matchingPreset == .custom)
        }
    }
}

// MARK: - makeSUT & Factories

private func makeSUT(
    pattern: RepeatIntervalType,
    frequency: Int = 1,
    dayOfWeek: Weekday? = nil,
    dayOfMonth: Int? = nil
) -> (RecurrenceRule, Date, Date, Calendar) {
    let sut = RecurrenceRule(
        pattern: pattern,
        frequency: frequency,
        dayOfWeek: dayOfWeek,
        dayOfMonth: dayOfMonth
    )
    let startDate = makeDate(day: 1)
    let endDate = makeDate(day: 15)
    let calendar = makeUTCCalendar()

    return (sut, startDate, endDate, calendar)
}

private func makeDate(year: Int = 2025, month: Int = 1, day: Int) -> Date {
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
