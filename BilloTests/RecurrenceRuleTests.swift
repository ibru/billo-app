//  Created by Jiri Urbasek on 11/26/25.

import Testing
import Foundation
@testable import Billo

@Suite("RecurrenceRule")
struct RecurrenceRuleTests {

    @Suite("generateOccurrences - Weekly")
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
    }

    @Suite("generateOccurrences - Monthly")
    struct MonthlyRecurrence {
        @Test func whenMonthly_thenGeneratesOccurrencesEveryMonth() {
            let startDate = makeDate(year: 2025, month: 1, day: 15)
            let endDate = makeDate(year: 2025, month: 4, day: 1)
            let sut = RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 15)

            let occurrences = sut.generateOccurrences(from: startDate, until: endDate, calendar: .current)

            #expect(occurrences.count == 3)
            #expect(occurrences[0] == makeDate(year: 2025, month: 1, day: 15))
            #expect(occurrences[1] == makeDate(year: 2025, month: 2, day: 15))
            #expect(occurrences[2] == makeDate(year: 2025, month: 3, day: 15))
        }

        @Test func whenMonthlyOn31st_thenAdjustsToLastDayOfMonthWithFewerDays() {
            let startDate = makeDate(year: 2025, month: 1, day: 31)
            let endDate = makeDate(year: 2025, month: 4, day: 1)
            let sut = RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 31)

            let occurrences = sut.generateOccurrences(from: startDate, until: endDate, calendar: .current)

            #expect(occurrences.count == 3)
            #expect(occurrences[0] == makeDate(year: 2025, month: 1, day: 31))
            #expect(occurrences[1] == makeDate(year: 2025, month: 2, day: 28))
            #expect(occurrences[2] == makeDate(year: 2025, month: 3, day: 31))
        }

        @Test func whenMonthlyWithFrequencyTwo_thenGeneratesOccurrencesEveryTwoMonths() {
            let startDate = makeDate(year: 2025, month: 1, day: 15)
            let endDate = makeDate(year: 2025, month: 6, day: 1)
            let sut = RecurrenceRule(pattern: .monthly, frequency: 2, dayOfMonth: 15)

            let occurrences = sut.generateOccurrences(from: startDate, until: endDate, calendar: .current)

            #expect(occurrences.count == 3)
            #expect(occurrences[0] == makeDate(year: 2025, month: 1, day: 15))
            #expect(occurrences[1] == makeDate(year: 2025, month: 3, day: 15))
            #expect(occurrences[2] == makeDate(year: 2025, month: 5, day: 15))
        }
    }

    @Suite("generateOccurrences - Yearly")
    struct YearlyRecurrence {
        @Test func whenYearly_thenGeneratesOccurrencesEveryYear() {
            let startDate = makeDate(year: 2025, month: 1, day: 15)
            let endDate = makeDate(year: 2028, month: 1, day: 1)
            let sut = RecurrenceRule(pattern: .yearly, frequency: 1)

            let occurrences = sut.generateOccurrences(from: startDate, until: endDate, calendar: .current)

            #expect(occurrences.count == 3)
            #expect(occurrences[0] == makeDate(year: 2025, month: 1, day: 15))
            #expect(occurrences[1] == makeDate(year: 2026, month: 1, day: 15))
            #expect(occurrences[2] == makeDate(year: 2027, month: 1, day: 15))
        }
    }

    @Suite("generateOccurrences - End Conditions")
    struct EndConditions {
        @Test func whenEndDateBeforeMaxDate_thenStopsAtEndDate() {
            let startDate = makeDate(year: 2025, month: 1, day: 1)
            let endDate = makeDate(year: 2025, month: 1, day: 22)
            let maxDate = makeDate(year: 2025, month: 3, day: 30)
            let sut = RecurrenceRule(
                pattern: .weekly,
                frequency: 1,
                endConditionType: .endDate,
                endDate: endDate
            )

            let occurrences = sut.generateOccurrences(from: startDate, until: maxDate, calendar: .current)

            // Jan 1, 8, 15, 22 = 4 weekly occurrences
            #expect(occurrences.count == 4)
            #expect(occurrences.last == endDate)
        }

        @Test func whenNeverEnds_thenStopsAtMaxDate() {
            let startDate = makeDate(year: 2025, month: 1, day: 1)
            let maxDate = makeDate(year: 2025, month: 1, day: 22)
            let sut = RecurrenceRule(pattern: .weekly, frequency: 1, endConditionType: .never)

            let occurrences = sut.generateOccurrences(from: startDate, until: maxDate, calendar: .current)

            // Jan 1, 8, 15, 22 = 4 weekly occurrences
            #expect(occurrences.count == 4)
            #expect(occurrences.last == maxDate)
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
    let calendar = Calendar.current

    return (sut, startDate, endDate, calendar)
}

private func makeDate(year: Int = 2025, month: Int = 1, day: Int) -> Date {
    let calendar = Calendar.current
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return calendar.date(from: components)!
}
