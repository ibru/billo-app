//  Created by Jiri Urbasek on 12/10/25.

import Testing
import SwiftData
import Foundation
@testable import Billo

@Suite("Income") @MainActor
struct IncomeTests {

    @Suite("generateOccurrences") @MainActor
    struct GenerateOccurrences {
        @Test func whenNoRecurrenceRule_thenReturnsSingleOccurrence() {
            let income = makeIncome(
                startDate: makeDate(day: 15)
            )
            let rangeStart = makeDate(day: 1)
            let rangeEnd = makeDate(day: 31)

            let occurrences = income.generateOccurrences(
                from: rangeStart,
                until: rangeEnd,
                calendar: .current
            )

            #expect(occurrences.count == 1)
            #expect(occurrences.first == income.startDate)
        }

        @Test func whenRecurrenceRuleIsMonthly_thenDelegatesToRule() {
            let rule = RecurrenceRule(pattern: .monthly, frequency: 1)
            let income = makeIncome(
                startDate: makeDate(month: 1, day: 1),
                recurrenceRule: rule
            )
            let rangeStart = makeDate(month: 1, day: 1)
            let rangeEnd = makeDate(month: 4, day: 1)

            let occurrences = income.generateOccurrences(
                from: rangeStart,
                until: rangeEnd,
                calendar: .current
            )

            #expect(occurrences.count == 4)
        }

        @Test func whenStartDateOutsideRange_thenReturnsEmpty() {
            let income = makeIncome(
                startDate: makeDate(month: 3, day: 1)
            )
            let rangeStart = makeDate(month: 1, day: 1)
            let rangeEnd = makeDate(month: 2, day: 28)

            let occurrences = income.generateOccurrences(
                from: rangeStart,
                until: rangeEnd,
                calendar: .current
            )

            #expect(occurrences.isEmpty)
        }

        @Test func whenEndDateSet_thenStopsGeneratingAfterEndDate() {
            let rule = RecurrenceRule(
                pattern: .monthly,
                frequency: 1,
                endConditionType: .endDate,
                endDate: makeDate(month: 2, day: 15)
            )
            let income = makeIncome(
                startDate: makeDate(month: 1, day: 1),
                recurrenceRule: rule
            )
            let rangeStart = makeDate(month: 1, day: 1)
            let rangeEnd = makeDate(month: 6, day: 1)

            let occurrences = income.generateOccurrences(
                from: rangeStart,
                until: rangeEnd,
                calendar: .current
            )

            #expect(occurrences.count == 2)
        }

        @Test func whenEndDateBeforeRangeStart_thenReturnsEmpty() {
            let rule = RecurrenceRule(
                pattern: .monthly,
                frequency: 1,
                endConditionType: .endDate,
                endDate: makeDate(month: 2, day: 1)
            )
            let income = makeIncome(
                startDate: makeDate(month: 1, day: 1),
                recurrenceRule: rule
            )
            let rangeStart = makeDate(month: 3, day: 1)
            let rangeEnd = makeDate(month: 6, day: 1)

            let occurrences = income.generateOccurrences(
                from: rangeStart,
                until: rangeEnd,
                calendar: .current
            )

            #expect(occurrences.isEmpty)
        }

        @Test func whenMonthlyIncomeStartsOn1st_thenAlwaysOccursOn1st() {
            let rule = RecurrenceRule(pattern: .monthly, frequency: 1)
            let income = makeIncome(
                startDate: makeDate(month: 1, day: 1),
                recurrenceRule: rule
            )
            let rangeStart = makeDate(month: 1, day: 1)
            let rangeEnd = makeDate(month: 4, day: 30)
            let calendar = Calendar.current

            let occurrences = income.generateOccurrences(
                from: rangeStart,
                until: rangeEnd,
                calendar: calendar
            )

            for occurrence in occurrences {
                let day = calendar.component(.day, from: occurrence)
                #expect(day == 1, "Occurrence should be on the 1st, got \(day)")
            }
        }

        @Test func whenWeeklyIncomeStartsOnFriday_thenAlwaysOccursOnFriday() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.firstWeekday = 1 // Sunday

            // Jan 3, 2025 is a Friday
            let friday = makeDate(month: 1, day: 3)
            let rule = RecurrenceRule(pattern: .weekly, frequency: 1)
            let income = makeIncome(
                startDate: friday,
                recurrenceRule: rule
            )
            let rangeStart = makeDate(month: 1, day: 1)
            let rangeEnd = makeDate(month: 2, day: 28)

            let occurrences = income.generateOccurrences(
                from: rangeStart,
                until: rangeEnd,
                calendar: calendar
            )

            for occurrence in occurrences {
                let weekday = calendar.component(.weekday, from: occurrence)
                #expect(weekday == 6, "Occurrence should be on Friday (weekday 6), got \(weekday)")
            }
        }

        @Test func whenQueryingLaterWindow_thenAnchorDoesNotDrift() {
            let rule = RecurrenceRule(pattern: .monthly, frequency: 1)
            let income = makeIncome(
                startDate: makeDate(month: 1, day: 15),
                recurrenceRule: rule
            )
            let calendar = Calendar.current

            // Query a window that starts 3 months after the anchor
            let rangeStart = makeDate(month: 4, day: 1)
            let rangeEnd = makeDate(month: 6, day: 30)

            let occurrences = income.generateOccurrences(
                from: rangeStart,
                until: rangeEnd,
                calendar: calendar
            )

            // Should have occurrences on the 15th of April, May, June
            #expect(occurrences.count == 3)
            for occurrence in occurrences {
                let day = calendar.component(.day, from: occurrence)
                #expect(day == 15, "Occurrence should be on the 15th, got \(day)")
            }
        }
    }

    @Suite("validation") @MainActor
    struct Validation {
        @Test func whenAmountIsZero_thenThrowsNonPositiveAmountError() {
            #expect(throws: IncomeValidationError.nonPositiveAmount) {
                try Income.create(
                    name: "Salary",
                    amount: 0,
                    currencyCode: "USD",
                    startDate: Date()
                )
            }
        }

        @Test func whenAmountIsNegative_thenThrowsNonPositiveAmountError() {
            #expect(throws: IncomeValidationError.nonPositiveAmount) {
                try Income.create(
                    name: "Salary",
                    amount: -100,
                    currencyCode: "USD",
                    startDate: Date()
                )
            }
        }

        @Test func whenNameIsEmpty_thenThrowsEmptyNameError() {
            #expect(throws: IncomeValidationError.emptyName) {
                try Income.create(
                    name: "",
                    amount: 1000,
                    currencyCode: "USD",
                    startDate: Date()
                )
            }
        }

        @Test func whenNameIsWhitespaceOnly_thenThrowsEmptyNameError() {
            #expect(throws: IncomeValidationError.emptyName) {
                try Income.create(
                    name: "   ",
                    amount: 1000,
                    currencyCode: "USD",
                    startDate: Date()
                )
            }
        }

        @Test func whenEndDateBeforeStartDate_thenThrowsEndDateError() {
            let startDate = makeDate(month: 6, day: 1)
            let recurrenceRule = RecurrenceRule(
                pattern: .monthly,
                frequency: 1,
                endConditionType: .endDate,
                endDate: makeDate(month: 5, day: 1)
            )

            #expect(throws: IncomeValidationError.endDateBeforeStartDate) {
                try Income.create(
                    name: "Salary",
                    amount: 1000,
                    currencyCode: "USD",
                    startDate: startDate,
                    recurrenceRule: recurrenceRule
                )
            }
        }

        @Test func whenValidInput_thenReturnsIncome() throws {
            let income = try Income.create(
                name: "  Monthly Salary  ",
                amount: 5000,
                currencyCode: "USD",
                startDate: Date()
            )

            #expect(income.name == "Monthly Salary") // Should be trimmed
            #expect(income.amount == 5000)
            #expect(income.currencyCode == "USD")
        }

        @Test func whenEndDateEqualsStartDate_thenSucceeds() throws {
            let date = makeDate(month: 6, day: 1)
            let recurrenceRule = RecurrenceRule(
                pattern: .monthly,
                frequency: 1,
                endConditionType: .endDate,
                endDate: date
            )

            let income = try Income.create(
                name: "Bonus",
                amount: 500,
                currencyCode: "USD",
                startDate: date,
                recurrenceRule: recurrenceRule
            )

            #expect(income.recurrenceRule?.endDate == income.startDate)
        }
    }
}

// MARK: - makeSUT & Factories

private func makeIncome(
    name: String = "Test Income",
    amount: Decimal = 1000,
    currencyCode: String = "USD",
    startDate: Date = Date(),
    recurrenceRule: RecurrenceRule? = nil
) -> Income {
    Income(
        name: name,
        amount: amount,
        currencyCode: currencyCode,
        startDate: startDate,
        recurrenceRule: recurrenceRule
    )
}

private func makeDate(year: Int = 2025, month: Int = 1, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return Calendar.current.date(from: components)!
}
