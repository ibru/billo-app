//  Created by Jiri Urbasek on 05/07/26.

import Testing
import SwiftData
import Foundation
@testable import Billo

@Suite("IncomeOccurrenceMaterializer") @MainActor
struct IncomeOccurrenceMaterializerTests {

    @Test func whenNoOccurrencesYetExist_thenAllPastDatesAreMaterialized() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let income = makeMonthlyIncome(
            amount: 1_000,
            startDate: makeDate(year: 2025, month: 1, day: 1, calendar: calendar),
            in: context
        )

        let result = try materializePast(
            for: income,
            today: makeDate(year: 2025, month: 4, day: 10, calendar: calendar),
            calendar: calendar,
            context: context
        )

        #expect(result.count == 4) // Jan 1, Feb 1, Mar 1, Apr 1 — all strictly before today
    }

    @Test func whenRunTwiceWithSameClock_thenNoDuplicatesAreCreated() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let income = makeMonthlyIncome(
            amount: 1_000,
            startDate: makeDate(year: 2025, month: 1, day: 1, calendar: calendar),
            in: context
        )
        let today = makeDate(year: 2025, month: 4, day: 10, calendar: calendar)

        _ = try materializePast(for: income, today: today, calendar: calendar, context: context)
        _ = try materializePast(for: income, today: today, calendar: calendar, context: context)

        let allRows = try context.fetch(FetchDescriptor<IncomeOccurrence>())
        #expect(allRows.count == 4)
    }

    @Test func whenAmountChangedBetweenRuns_thenExistingRowsKeepOldAmount() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let income = makeMonthlyIncome(
            amount: 1_000,
            startDate: makeDate(year: 2025, month: 1, day: 1, calendar: calendar),
            in: context
        )
        let today = makeDate(year: 2025, month: 4, day: 10, calendar: calendar)

        let firstSnapshot = IncomeSnapshot(income: income)
        _ = try IncomeOccurrenceMaterializer().materializePastOccurrences(
            for: firstSnapshot,
            income: income,
            upTo: today,
            calendar: calendar,
            context: context
        )
        try context.save()

        income.amount = 2_000
        let secondSnapshot = IncomeSnapshot(income: income)
        _ = try IncomeOccurrenceMaterializer().materializePastOccurrences(
            for: secondSnapshot,
            income: income,
            upTo: today,
            calendar: calendar,
            context: context
        )
        try context.save()

        let allAmounts = try context
            .fetch(FetchDescriptor<IncomeOccurrence>())
            .map(\.incomeAmount)
            .sorted(by: <)
        #expect(allAmounts == [1_000, 1_000, 1_000, 1_000])
    }

    @Test func whenScheduleChangedBetweenRuns_thenPostEditPastDatesAreNotBackfilled() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let income = makeMonthlyIncome(
            amount: 1_000,
            startDate: makeDate(year: 2025, month: 1, day: 1, calendar: calendar),
            in: context
        )
        let today = makeDate(year: 2025, month: 4, day: 10, calendar: calendar)

        let preEditSnapshot = IncomeSnapshot(income: income)
        _ = try IncomeOccurrenceMaterializer().materializePastOccurrences(
            for: preEditSnapshot,
            income: income,
            upTo: today,
            calendar: calendar,
            context: context
        )
        try context.save()

        // Schedule edit: anchor the recurrence on the 15th, bump the amount,
        // and (as BillsModel.updateIncome would) advance the materialization
        // start date to "today" so the new schedule cannot retroactively
        // project past dates.
        income.startDate = makeDate(year: 2025, month: 1, day: 15, calendar: calendar)
        income.amount = 2_000
        income.materializationStartDate = today

        let postEditSnapshot = IncomeSnapshot(income: income)
        _ = try IncomeOccurrenceMaterializer().materializePastOccurrences(
            for: postEditSnapshot,
            income: income,
            upTo: today,
            calendar: calendar,
            context: context
        )
        try context.save()

        let rows = try context.fetch(FetchDescriptor<IncomeOccurrence>())
        let oldRows = rows.filter { calendar.component(.day, from: $0.date) == 1 }
        let newRows = rows.filter { calendar.component(.day, from: $0.date) == 15 }

        // Pre-edit produced 4 rows on the 1st @ 1000 (Jan, Feb, Mar, Apr 1).
        // Post-edit must NOT backfill any 15th-of-month past rows — the new
        // schedule applies going forward only ("snapshot-and-go" semantics).
        #expect(oldRows.count == 4)
        #expect(oldRows.allSatisfy { $0.incomeAmount == 1_000 })
        #expect(newRows.isEmpty)
    }

    @Test func whenScheduleEditedAndLaterRefreshSeesNewlyDuePostEditDate_thenItIsMaterializedAtNewAmount() throws {
        // After an Apr-10 schedule edit, time advances to May 11. The first
        // new-schedule occurrence on/after the edit moment (Apr 15) is now in
        // the past and should be materialized at the new amount, while
        // pre-edit rows on the 1st are untouched. Tests bypass
        // `BillsModel.updateIncome`, so they must simulate the edit by setting
        // `materializationStartDate` directly — mirroring what the model layer
        // does on every schedule mutation.
        let calendar = utcCalendar()
        let context = try makeContext()
        let income = makeMonthlyIncome(
            amount: 1_000,
            startDate: makeDate(year: 2025, month: 1, day: 1, calendar: calendar),
            in: context
        )

        // Steady-state up to the edit date.
        let editDay = makeDate(year: 2025, month: 4, day: 10, calendar: calendar)
        _ = try materializePast(
            for: income,
            today: editDay,
            calendar: calendar,
            context: context
        )

        // User edits on Apr 10 — schedule moves to monthly-on-the-15th and the
        // amount bumps to 2000.
        income.startDate = makeDate(year: 2025, month: 1, day: 15, calendar: calendar)
        income.amount = 2_000
        income.materializationStartDate = editDay

        // The Apr-10 refresh attempts materialization with the new snapshot.
        // Snapshot generates Jan/Feb/Mar 15 — all `< editDay` so the filter
        // blocks them. No backfill.
        _ = try materializePast(
            for: income,
            today: editDay,
            calendar: calendar,
            context: context
        )

        // Time advances to May 11. Apr 15 (>= editDay) is now past and gets
        // materialized at the new amount.
        _ = try materializePast(
            for: income,
            today: makeDate(year: 2025, month: 5, day: 11, calendar: calendar),
            calendar: calendar,
            context: context
        )

        let rows = try context
            .fetch(FetchDescriptor<IncomeOccurrence>())
            .sorted { $0.date < $1.date }

        let april15 = makeDate(year: 2025, month: 4, day: 15, calendar: calendar)
        let april15Row = try #require(rows.first { calendar.isDate($0.date, inSameDayAs: april15) })
        #expect(april15Row.incomeAmount == 2_000)

        let firstOfMonthRows = rows.filter { calendar.component(.day, from: $0.date) == 1 }
        #expect(firstOfMonthRows.count == 4)
        #expect(firstOfMonthRows.allSatisfy { $0.incomeAmount == 1_000 })
    }

    @Test func whenAnExcludedRowExists_thenMaterializerDoesNotRecreateIt() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let income = makeMonthlyIncome(
            amount: 1_000,
            startDate: makeDate(year: 2025, month: 1, day: 1, calendar: calendar),
            in: context
        )
        let today = makeDate(year: 2025, month: 4, day: 10, calendar: calendar)

        _ = try materializePast(for: income, today: today, calendar: calendar, context: context)

        // User skips the February occurrence.
        let februaryDate = makeDate(year: 2025, month: 2, day: 1, calendar: calendar)
        let februaryRow = try #require(
            try context.fetch(FetchDescriptor<IncomeOccurrence>())
                .first { calendar.isDate($0.date, inSameDayAs: februaryDate) }
        )
        februaryRow.isExcluded = true
        try context.save()

        // Re-run materializer; idempotency must respect the skip.
        _ = try materializePast(for: income, today: today, calendar: calendar, context: context)

        let februaryRowsAfter = try context.fetch(FetchDescriptor<IncomeOccurrence>())
            .filter { calendar.isDate($0.date, inSameDayAs: februaryDate) }
        #expect(februaryRowsAfter.count == 1)
        #expect(februaryRowsAfter.first?.isExcluded == true)
    }

    @Test func whenRelationshipInverseIsEmptyButRowsExistInStore_thenMaterializerDoesNotRecreateThem() throws {
        // Simulates a CloudKit eventual-consistency window: the persisted rows
        // are present in the main store, but the `Income.materializedOccurrences`
        // inverse hasn't propagated yet. The materializer must trust the
        // explicitly-passed existingRows (sourced from a fresh store fetch) and
        // skip re-insertion — otherwise we'd duplicate the row at the same key.
        let calendar = utcCalendar()
        let context = try makeContext()
        let income = makeMonthlyIncome(
            amount: 1_000,
            startDate: makeDate(year: 2025, month: 1, day: 1, calendar: calendar),
            in: context
        )

        // Insert a row that is *not* attached to `income.materializedOccurrences`
        // (CloudKit-lag stand-in: relationship inverse is empty for this income).
        let snapshot = IncomeSnapshot(income: income)
        let januaryDate = makeDate(year: 2025, month: 1, day: 1, calendar: calendar)
        let key = snapshot.occurrenceKey(for: januaryDate)
        let orphanedFromInverse = IncomeOccurrence(
            occurrenceKey: key,
            date: januaryDate,
            incomeName: "Salary",
            incomeAmount: 1_000,
            incomeCurrencyCode: "USD",
            income: nil // ← key bit: inverse not yet linked
        )
        context.insert(orphanedFromInverse)
        try context.save()

        // Confirm the inverse is genuinely empty for this income (CloudKit-lag
        // stand-in).
        #expect((income.materializedOccurrences ?? []).isEmpty)

        // Caller (BillsModel.refresh) hoists a global fetch and passes the
        // relevant slice. The materializer must honor it.
        let allRows = try context.fetch(FetchDescriptor<IncomeOccurrence>())
        let inserted = try IncomeOccurrenceMaterializer().materializePastOccurrences(
            for: snapshot,
            income: income,
            existingRows: allRows.filter { $0.occurrenceKey.hasPrefix("\(income.stableID):") },
            upTo: makeDate(year: 2025, month: 4, day: 10, calendar: calendar),
            calendar: calendar,
            context: context
        )

        // January key was already in existingRows → skipped.
        let insertedJanuary = inserted.filter {
            calendar.isDate($0.date, inSameDayAs: januaryDate)
        }
        #expect(insertedJanuary.isEmpty)

        // The other past dates (Feb, Mar) are still missing → materialized.
        let allFebMar = try context.fetch(FetchDescriptor<IncomeOccurrence>())
            .filter { calendar.component(.day, from: $0.date) == 1 }
            .filter { (2...3).contains(calendar.component(.month, from: $0.date)) }
        #expect(allFebMar.count == 2)
    }

    @Test func whenConvenienceOverloadUsedWithoutExistingRows_thenItFetchesFromStore() throws {
        // The no-`existingRows:` overload is used from `updateIncome` and
        // `deleteIncome`. It must internally fetch from the main store so it
        // gets the same inverse-lag protection as the explicit-list overload.
        let calendar = utcCalendar()
        let context = try makeContext()
        let income = makeMonthlyIncome(
            amount: 1_000,
            startDate: makeDate(year: 2025, month: 1, day: 1, calendar: calendar),
            in: context
        )

        // Seed a January row with no inverse link.
        let snapshot = IncomeSnapshot(income: income)
        let januaryDate = makeDate(year: 2025, month: 1, day: 1, calendar: calendar)
        let key = snapshot.occurrenceKey(for: januaryDate)
        context.insert(IncomeOccurrence(
            occurrenceKey: key,
            date: januaryDate,
            incomeName: "Salary",
            incomeAmount: 1_000,
            incomeCurrencyCode: "USD",
            income: nil
        ))
        try context.save()

        _ = try IncomeOccurrenceMaterializer().materializePastOccurrences(
            for: snapshot,
            income: income,
            upTo: makeDate(year: 2025, month: 4, day: 10, calendar: calendar),
            calendar: calendar,
            context: context
        )

        // The January row should not have been duplicated. Total = January
        // orphan + Feb + Mar + Apr 1 = 4.
        let allRows = try context.fetch(FetchDescriptor<IncomeOccurrence>())
        #expect(allRows.count == 4)
        let januaryRows = allRows.filter { calendar.isDate($0.date, inSameDayAs: januaryDate) }
        #expect(januaryRows.count == 1)
    }

    @Test func whenIncomeHasNoRecurrenceRule_andStartDateIsInThePast_thenSingleRowIsMaterialized() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let income = Income(
            name: "Bonus",
            amount: 500,
            startDate: makeDate(year: 2025, month: 2, day: 14, calendar: calendar),
            recurrenceRule: nil
        )
        context.insert(income)

        let result = try materializePast(
            for: income,
            today: makeDate(year: 2025, month: 4, day: 10, calendar: calendar),
            calendar: calendar,
            context: context
        )

        #expect(result.count == 1)
        #expect(result.first?.incomeName == "Bonus")
        #expect(result.first?.incomeAmount == 500)
    }

    @Test func whenSnapshotProducesGapBetweenExistingRows_thenGapDateIsBackfilled() throws {
        // Finding 4 free fix: with the latest-existing watermark removed, a
        // partial-sync gap (e.g. CloudKit delivered Jan and Mar but not Feb)
        // now recovers on the next refresh. Schedule-edit safety is enforced
        // by `materializationStartDate`, not by hiding the gap.
        let calendar = utcCalendar()
        let context = try makeContext()
        let income = makeMonthlyIncome(
            amount: 1_000,
            startDate: makeDate(year: 2025, month: 1, day: 1, calendar: calendar),
            in: context
        )

        // Hand-place rows at Jan 1 and Mar 1, intentionally leaving Feb 1 absent.
        let snapshot = IncomeSnapshot(income: income)
        let janKey = snapshot.occurrenceKey(for: makeDate(year: 2025, month: 1, day: 1, calendar: calendar))
        let marKey = snapshot.occurrenceKey(for: makeDate(year: 2025, month: 3, day: 1, calendar: calendar))

        context.insert(IncomeOccurrence(
            occurrenceKey: janKey,
            date: makeDate(year: 2025, month: 1, day: 1, calendar: calendar),
            incomeName: "Salary",
            incomeAmount: 1_000,
            incomeCurrencyCode: "USD",
            income: income
        ))
        context.insert(IncomeOccurrence(
            occurrenceKey: marKey,
            date: makeDate(year: 2025, month: 3, day: 1, calendar: calendar),
            incomeName: "Salary",
            incomeAmount: 1_000,
            incomeCurrencyCode: "USD",
            income: income
        ))
        try context.save()

        _ = try materializePast(
            for: income,
            today: makeDate(year: 2025, month: 4, day: 10, calendar: calendar),
            calendar: calendar,
            context: context
        )

        let months = try context.fetch(FetchDescriptor<IncomeOccurrence>())
            .map { calendar.component(.month, from: $0.date) }
            .sorted()

        // All four past dates exist now — Feb gap filled, Apr 1 added.
        #expect(months == [1, 2, 3, 4])
    }

    @Test func whenTodayIsAnOccurrenceDate_thenItIsNotYetMaterialized() throws {
        let calendar = utcCalendar()
        let context = try makeContext()
        let income = makeMonthlyIncome(
            amount: 1_000,
            startDate: makeDate(year: 2025, month: 1, day: 1, calendar: calendar),
            in: context
        )

        // Today is March 1 — exactly an occurrence date.
        let today = makeDate(year: 2025, month: 3, day: 1, calendar: calendar)
        _ = try materializePast(for: income, today: today, calendar: calendar, context: context)

        let rows = try context.fetch(FetchDescriptor<IncomeOccurrence>())
        let containsTodayRow = rows.contains { calendar.isDate($0.date, inSameDayAs: today) }
        #expect(containsTodayRow == false)
        // Only Jan 1 and Feb 1 should be materialized.
        #expect(rows.count == 2)
    }
}

// MARK: - makeSUT & Factories

@MainActor
private func materializePast(
    for income: Income,
    today: Date,
    calendar: Calendar,
    context: ModelContext
) throws -> [IncomeOccurrence] {
    let snapshot = IncomeSnapshot(income: income)
    let inserted = try IncomeOccurrenceMaterializer().materializePastOccurrences(
        for: snapshot,
        income: income,
        upTo: today,
        calendar: calendar,
        context: context
    )
    try context.save()
    return inserted
}

@MainActor
private func makeMonthlyIncome(
    name: String = "Salary",
    amount: Decimal,
    startDate: Date,
    in context: ModelContext
) -> Income {
    let income = Income(
        name: name,
        amount: amount,
        startDate: startDate,
        recurrenceRule: RecurrenceRule(pattern: .monthly, frequency: 1)
    )
    context.insert(income)
    return income
}

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

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.locale = Locale(identifier: "en_US")
    return calendar
}

private func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return calendar.date(from: components)!
}
