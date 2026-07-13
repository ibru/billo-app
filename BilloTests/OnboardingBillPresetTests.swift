//  Created by Jiri Urbasek on 7/10/26.

import Foundation
import Testing
@testable import Billo

@Suite("OnboardingBillPreset")
struct OnboardingBillPresetTests {
    @Suite("catalog")
    struct Catalog {
        @Test func whenListingPresets_thenIdentifiersAreUnique() {
            let ids = OnboardingBillPreset.all.map(\.id)
            #expect(Set(ids).count == ids.count)
        }

        @Test func whenListingPresets_thenAllHavePositiveAmountsAndValidDueDays() {
            for preset in OnboardingBillPreset.all {
                #expect(preset.defaultAmount > 0)
                #expect((1...31).contains(preset.defaultDueDay))
            }
        }

        @Test func whenListingPresets_thenCatalogStaysUnderTheFreeBillLimit() {
            // Presets are the only way to add bills during onboarding and
            // each can be added once, so their count is the onboarding
            // ceiling. The free tier allows 15 bills — the catalog must stay
            // below it so onboarding can never max out (or overshoot) the
            // free allowance before the user even reaches the app.
            #expect(OnboardingBillPreset.all.count <= 12)
        }
    }

    @Suite("nextDueDate(dayOfMonth:)")
    struct NextDueDate {
        @Test func whenDayIsLaterThisMonth_thenDueDateFallsInCurrentMonth() throws {
            let march10 = try makeDate(year: 2026, month: 3, day: 10)
            let dueDate = OnboardingBillPreset.nextDueDate(dayOfMonth: 15, from: march10, calendar: utcCalendar)
            #expect(dueDate == (try makeDate(year: 2026, month: 3, day: 15)))
        }

        @Test func whenDayIsToday_thenDueDateIsToday() throws {
            let march10 = try makeDate(year: 2026, month: 3, day: 10)
            let dueDate = OnboardingBillPreset.nextDueDate(dayOfMonth: 10, from: march10, calendar: utcCalendar)
            #expect(dueDate == march10)
        }

        @Test func whenDayAlreadyPassed_thenDueDateRollsToNextMonth() throws {
            let march10 = try makeDate(year: 2026, month: 3, day: 10)
            let dueDate = OnboardingBillPreset.nextDueDate(dayOfMonth: 5, from: march10, calendar: utcCalendar)
            #expect(dueDate == (try makeDate(year: 2026, month: 4, day: 5)))
        }

        @Test func whenDayPassedInDecember_thenDueDateRollsAcrossYearBoundary() throws {
            let december20 = try makeDate(year: 2026, month: 12, day: 20)
            let dueDate = OnboardingBillPreset.nextDueDate(dayOfMonth: 5, from: december20, calendar: utcCalendar)
            #expect(dueDate == (try makeDate(year: 2027, month: 1, day: 5)))
        }

        @Test func whenDayExceedsMonthLength_thenDueDateClampsToLastDay() throws {
            let february10 = try makeDate(year: 2026, month: 2, day: 10)
            let dueDate = OnboardingBillPreset.nextDueDate(dayOfMonth: 31, from: february10, calendar: utcCalendar)
            #expect(dueDate == (try makeDate(year: 2026, month: 2, day: 28)))
        }

        @Test func whenDayExceedsMonthLengthInLeapYear_thenDueDateClampsToFebruary29() throws {
            let february10LeapYear = try makeDate(year: 2028, month: 2, day: 10)
            let dueDate = OnboardingBillPreset.nextDueDate(dayOfMonth: 31, from: february10LeapYear, calendar: utcCalendar)
            #expect(dueDate == (try makeDate(year: 2028, month: 2, day: 29)))
        }
    }

    @Suite("monthlyEquivalent")
    struct MonthlyEquivalent {
        @Test func whenBillIsMonthly_thenMonthlyCostEqualsAmount() {
            #expect(OnboardingBillPreset.monthlyEquivalent(amount: 120, recurrence: .monthly) == 120)
        }

        @Test func whenBillIsWeekly_thenMonthlyCostIsFiftyTwoWeeksSpreadOverTwelveMonths() {
            #expect(OnboardingBillPreset.monthlyEquivalent(amount: 12, recurrence: .weekly) == 52)
        }

        @Test func whenBillIsBiweekly_thenMonthlyCostIsTwentySixPaymentsSpreadOverTwelveMonths() {
            #expect(OnboardingBillPreset.monthlyEquivalent(amount: 12, recurrence: .biweekly) == 26)
        }

        @Test func whenBillIsOneTime_thenItCountsOnceTowardTheMonth() {
            #expect(OnboardingBillPreset.monthlyEquivalent(amount: 300, recurrence: .none) == 300)
        }
    }
}

// MARK: - makeSUT & Factories

private let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
    return calendar
}()

private func makeDate(year: Int, month: Int, day: Int) throws -> Date {
    try #require(utcCalendar.date(from: DateComponents(year: year, month: month, day: day)))
}
