//  Created by Jiri Urbasek on 05/07/26.

import Testing
import SwiftData
import Foundation
@testable import Billo

@Suite("IncomeOccurrence") @MainActor
struct IncomeOccurrenceTests {

    @Test func whenTwoOccurrencesShareAKey_thenTheyAreConsideredDuplicates() throws {
        let context = try makeContext()
        let income = makeIncome(in: context)
        let date = makeDate(year: 2025, month: 1, day: 1)

        let first = makeOccurrence(for: income, on: date, in: context)
        let second = makeOccurrence(for: income, on: date, in: context)
        try context.save()

        // Both rows must end up with the same `occurrenceKey` — that's the
        // contract that drives dedupe at read time and skip-propagation at write.
        #expect(first.occurrenceKey == second.occurrenceKey)
    }

    @Test func whenIncomeIsDeleted_thenOccurrencesAreNullifiedNotDeleted() throws {
        let context = try makeContext()
        let income = makeIncome(in: context)
        let occurrence = makeOccurrence(
            for: income,
            on: makeDate(year: 2025, month: 1, day: 1),
            in: context
        )
        try context.save()

        context.delete(income)
        try context.save()

        let allOccurrences = try context.fetch(FetchDescriptor<IncomeOccurrence>())
        #expect(allOccurrences.count == 1)
        #expect(allOccurrences.first?.income == nil)
        // Ensure the snapshot survives so historical UI can still render it.
        #expect(occurrence.incomeName.isEmpty == false)
        #expect(occurrence.incomeAmount > 0)
    }

    @Test func whenTwoDatesShareUTCDay_thenUtcDateKeyAgrees() {
        // 02:00 UTC and 23:00 UTC on 2025-01-15. In Pacific time, the early one
        // is still 2025-01-14; in Tokyo, the late one is already 2025-01-16.
        // The UTC-keyed identity must agree on "2025-01-15" for both.
        let early = makeUTCDate(year: 2025, month: 1, day: 15, hour: 2)
        let late = makeUTCDate(year: 2025, month: 1, day: 15, hour: 23)

        let earlyKey = early.utcDayKey
        let lateKey = late.utcDayKey

        #expect(earlyKey == "2025-01-15")
        #expect(lateKey == "2025-01-15")
    }

    @Test func whenTwoDatesAreSameLocalDayButDifferentUTCDays_thenUtcDateKeysDiffer() {
        // 23:00 UTC on 2025-01-15 — that's 2025-01-16 in Tokyo (UTC+9).
        // 02:00 UTC on 2025-01-16 — that's 2025-01-16 in Tokyo too, but a
        // *different* UTC day. UTC-keyed identity must distinguish them.
        let utc15Late = makeUTCDate(year: 2025, month: 1, day: 15, hour: 23)
        let utc16Early = makeUTCDate(year: 2025, month: 1, day: 16, hour: 2)

        #expect(utc15Late.utcDayKey == "2025-01-15")
        #expect(utc16Early.utcDayKey == "2025-01-16")
    }

    @Test func whenLocalMidnightIsEastOfUTC_thenUtcKeyTrailsLocalCalendarDay() throws {
        // Timezone-drift gotcha (one direction): if a user east of UTC picks
        // "Jan 15" via the local DatePicker, the resulting local-midnight
        // `Date` instant is on the *prior* UTC day, so the UTC key trails the
        // displayed local day by one. Mirrors `Bill.swift`'s identity rule.
        var prague = Calendar(identifier: .gregorian)
        prague.timeZone = try #require(TimeZone(identifier: "Europe/Prague"))
        let pragueMidnight = try #require(
            prague.date(from: DateComponents(year: 2025, month: 1, day: 15, hour: 0))
        )
        // Prague is UTC+1 in January, so Jan 15 00:00 CET = Jan 14 23:00 UTC.
        #expect(pragueMidnight.utcDayKey == "2025-01-14")
    }

    @Test func whenLocalLateEveningIsWestOfUTC_thenUtcKeyLeadsLocalCalendarDay() throws {
        // Symmetric direction: a user west of UTC who picks a late-evening
        // time sees the UTC key on the *next* day. (Pacific is UTC-8 in Jan,
        // so Jan 15 23:30 PST = Jan 16 07:30 UTC → key "2025-01-16".)
        var pacific = Calendar(identifier: .gregorian)
        pacific.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let pacificLate = try #require(
            pacific.date(from: DateComponents(year: 2025, month: 1, day: 15, hour: 23, minute: 30))
        )
        #expect(pacificLate.utcDayKey == "2025-01-16")
    }

    @Test func whenSourceDateIsStoredAtLocalNoon_thenUtcKeyMatchesLocalCalendarDayForReasonableTimezones() throws {
        // Mitigation hint baked into a test: anchoring the source `Date` at
        // local noon keeps key and displayed day aligned for any timezone
        // within ±12h of UTC. Useful pattern for any future picker that wants
        // to avoid the drift.
        var pacific = Calendar(identifier: .gregorian)
        pacific.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let noonPST = try #require(
            pacific.date(from: DateComponents(year: 2025, month: 1, day: 15, hour: 12))
        )
        var prague = Calendar(identifier: .gregorian)
        prague.timeZone = try #require(TimeZone(identifier: "Europe/Prague"))
        let noonCET = try #require(
            prague.date(from: DateComponents(year: 2025, month: 1, day: 15, hour: 12))
        )

        #expect(noonPST.utcDayKey == "2025-01-15")
        #expect(noonCET.utcDayKey == "2025-01-15")
    }

    @Test func whenAnyRowInDedupeGroupIsExcluded_thenWholeKeyIsHiddenFromViews() throws {
        // Schema-level proof of the CR2-2 fix: the read-time dedupe must treat
        // "any sibling at this key is excluded" as "the key is hidden",
        // regardless of which row would win the createdDate tiebreak.
        let context = try makeContext()
        let income = makeIncome(in: context)
        let date = makeDate(year: 2025, month: 1, day: 1)

        let earlier = makeOccurrence(for: income, on: date, in: context)
        earlier.createdDate = makeDate(year: 2024, month: 12, day: 1)

        let later = makeOccurrence(for: income, on: date, in: context)
        later.createdDate = makeDate(year: 2025, month: 2, day: 1)
        later.isExcluded = true
        later.excludedDate = makeDate(year: 2025, month: 4, day: 1)

        try context.save()

        let allKeys = try context
            .fetch(FetchDescriptor<IncomeOccurrence>())
            .map(\.occurrenceKey)
        // Both rows share the same key — the dedupe group below should hide it.
        #expect(Set(allKeys).count == 1)
        #expect(allKeys.count == 2)
        // (Behavioral assertion lives in BillsModelTests where `incomeOccurrenceItems`
        //  exercises the dedupe path; this test locks down the schema invariant
        //  that two rows can in fact share the same `occurrenceKey`.)
    }

    @Test func whenOccurrenceIsExcluded_thenItPersistsAcrossFetch() throws {
        let context = try makeContext()
        let income = makeIncome(in: context)
        let occurrence = makeOccurrence(
            for: income,
            on: makeDate(year: 2025, month: 1, day: 1),
            in: context
        )
        let excludedAt = Date()
        occurrence.isExcluded = true
        occurrence.excludedDate = excludedAt
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<IncomeOccurrence>()).first)
        #expect(fetched.isExcluded == true)
        #expect(fetched.excludedDate == excludedAt)
    }
}

// MARK: - makeSUT & Factories

@MainActor
private func makeContext() throws -> ModelContext {
    let schema = Schema([
        Bill.self,
        PaymentEntry.self,
        IssuedOccurrence.self,
        Income.self,
        IncomeOccurrence.self,
        RecurrenceRule.self
    ])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    return ModelContext(container)
}

@MainActor
@discardableResult
private func makeIncome(
    name: String = "Salary",
    amount: Decimal = 1_000,
    in context: ModelContext
) -> Income {
    let income = Income(
        name: name,
        amount: amount,
        startDate: makeDate(year: 2025, month: 1, day: 1)
    )
    context.insert(income)
    return income
}

@MainActor
@discardableResult
private func makeOccurrence(
    for income: Income,
    on date: Date,
    in context: ModelContext
) -> IncomeOccurrence {
    let calendar = utcCalendar()
    let snapshot = IncomeSnapshot(income: income)
    let key = snapshot.occurrenceKey(for: date)
    let occurrence = IncomeOccurrence(
        occurrenceKey: key,
        date: date,
        incomeName: income.name,
        incomeAmount: income.amount,
        incomeCurrencyCode: income.currencyCode,
        income: income
    )
    context.insert(occurrence)
    return occurrence
}

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.locale = Locale(identifier: "en_US")
    return calendar
}

private func makeDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return utcCalendar().date(from: components)!
}

private func makeUTCDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    return utcCalendar().date(from: components)!
}
