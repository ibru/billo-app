//  Created by Jiri Urbasek on 1/20/26.

import Testing
import Foundation
@testable import Billo

@Suite("RecurrencePreset") @MainActor
struct RecurrencePresetTests {

    @Suite("buildRecurrenceRule")
    @MainActor struct BuildRecurrenceRule {
        @Test func whenPresetNone_thenBuildsNilRule() {
            let rule = RecurrencePreset.none.buildRecurrenceRule(
                intervalType: .monthly,
                frequency: 1,
                dayOfWeek: .monday,
                dayOfMonth: 1
            )

            #expect(rule == nil)
        }

        @Test func whenPresetWeekly_thenBuildsWeeklyRuleWithFrequencyOne() throws {
            let builtRule = RecurrencePreset.weekly.buildRecurrenceRule(
                intervalType: .monthly,
                frequency: 12,
                dayOfWeek: .tuesday,
                dayOfMonth: 20
            )

            let rule = try #require(builtRule)
            #expect(rule.pattern == .weekly)
            #expect(rule.frequency == 1)
            #expect(rule.dayOfWeek == .tuesday)
            #expect(rule.dayOfMonth == nil)
        }

        @Test func whenPresetBiweekly_thenBuildsWeeklyRuleWithFrequencyTwo() throws {
            let builtRule = RecurrencePreset.biweekly.buildRecurrenceRule(
                intervalType: .monthly,
                frequency: 12,
                dayOfWeek: .friday,
                dayOfMonth: 20
            )

            let rule = try #require(builtRule)
            #expect(rule.pattern == .weekly)
            #expect(rule.frequency == 2)
            #expect(rule.dayOfWeek == .friday)
            #expect(rule.dayOfMonth == nil)
        }

        @Test func whenPresetMonthly_thenBuildsMonthlyRuleWithFrequencyOne() throws {
            let builtRule = RecurrencePreset.monthly.buildRecurrenceRule(
                intervalType: .weekly,
                frequency: 12,
                dayOfWeek: .monday,
                dayOfMonth: 20
            )

            let rule = try #require(builtRule)
            #expect(rule.pattern == .monthly)
            #expect(rule.frequency == 1)
            #expect(rule.dayOfWeek == nil)
            #expect(rule.dayOfMonth == 20)
        }

        @Test func whenPresetCustomWeekly_thenBuildsWeeklyRuleWithProvidedFrequencyAndDayOfWeek() throws {
            let builtRule = RecurrencePreset.custom.buildRecurrenceRule(
                intervalType: .weekly,
                frequency: 3,
                dayOfWeek: .wednesday,
                dayOfMonth: 10
            )

            let rule = try #require(builtRule)
            #expect(rule.pattern == .weekly)
            #expect(rule.frequency == 3)
            #expect(rule.dayOfWeek == .wednesday)
            #expect(rule.dayOfMonth == nil)
        }

        @Test func whenPresetCustomMonthly_thenBuildsMonthlyRuleWithProvidedFrequencyAndDayOfMonth() throws {
            let builtRule = RecurrencePreset.custom.buildRecurrenceRule(
                intervalType: .monthly,
                frequency: 3,
                dayOfWeek: .wednesday,
                dayOfMonth: 10
            )

            let rule = try #require(builtRule)
            #expect(rule.pattern == .monthly)
            #expect(rule.frequency == 3)
            #expect(rule.dayOfWeek == nil)
            #expect(rule.dayOfMonth == 10)
        }

        @Test func whenPresetCustomYearly_thenBuildsYearlyRuleWithoutDayFields() throws {
            let builtRule = RecurrencePreset.custom.buildRecurrenceRule(
                intervalType: .yearly,
                frequency: 2,
                dayOfWeek: .sunday,
                dayOfMonth: 31
            )

            let rule = try #require(builtRule)
            #expect(rule.pattern == .yearly)
            #expect(rule.frequency == 2)
            #expect(rule.dayOfWeek == nil)
            #expect(rule.dayOfMonth == nil)
        }
    }

    @Suite("endCondition")
    @MainActor struct EndCondition {
        @Test func whenEndConditionNever_thenBuildRuleWithoutEndDate() throws {
            let providedEndDate = Date(timeIntervalSince1970: 1234)

            let builtRule = RecurrencePreset.weekly.buildRecurrenceRule(
                intervalType: .weekly,
                frequency: 1,
                dayOfWeek: .monday,
                dayOfMonth: 1,
                endConditionType: .never,
                endDate: providedEndDate
            )

            let rule = try #require(builtRule)
            #expect(rule.endConditionType == .never)
            #expect(rule.endDate == nil)
        }

        @Test func whenEndConditionEndDate_thenBuildRuleWithEndDate() throws {
            let endDate = Date(timeIntervalSince1970: 5678)

            let builtRule = RecurrencePreset.monthly.buildRecurrenceRule(
                intervalType: .monthly,
                frequency: 1,
                dayOfWeek: .monday,
                dayOfMonth: 1,
                endConditionType: .endDate,
                endDate: endDate
            )

            let rule = try #require(builtRule)
            #expect(rule.endConditionType == .endDate)
            #expect(rule.endDate == endDate)
        }
    }
}
