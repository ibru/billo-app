//  Created by Jiri Urbasek on 07/01/26.

import Testing
import SwiftData
import Foundation
@testable import Billo

@MainActor
@Suite("Bill reschedule support")
struct BillRescheduleTests {

    // MARK: - nextDisplayDueDate

    @MainActor
    @Suite("nextDisplayDueDate")
    struct NextDisplayDueDate {
        @Test func whenNonRecurringBill_thenReturnsBaseDueDate() throws {
            let calendar = utcCalendar()
            let baseDue = makeDate(year: 2025, month: 3, day: 10)
            let (_, context) = try makeModel(referenceDate: makeDate(year: 2025, month: 1, day: 1), calendar: calendar)
            let bill = makeBill(dueDate: baseDue, rule: nil, calendar: calendar, in: context)

            #expect(bill.nextDisplayDueDate(referenceDate: makeDate(year: 2025, month: 1, day: 1), calendar: calendar) == baseDue)
        }

        @Test func whenRecurringBillWithFutureAnchor_thenReturnsAnchor() throws {
            let calendar = utcCalendar()
            let today = makeDate(year: 2025, month: 1, day: 1)
            let anchor = makeDate(year: 2025, month: 1, day: 2)
            let (model, context) = try makeModel(referenceDate: today, calendar: calendar)
            _ = makeBill(dueDate: anchor, rule: monthly(onDay: 2), calendar: calendar, in: context)
            try context.save()
            try model.refresh()

            let bill = model.bills[0]
            #expect(bill.nextDisplayDueDate(referenceDate: today, calendar: calendar) == anchor)
        }

        @Test func whenAllPastOccurrencesPaid_thenReturnsNextUnpaidFutureDate() async throws {
            let calendar = utcCalendar()
            let today = makeDate(year: 2025, month: 7, day: 1)
            let anchor = makeDate(year: 2025, month: 2, day: 2)
            let (model, context) = try makeModel(referenceDate: today, calendar: calendar)
            _ = makeBill(dueDate: anchor, amount: 100, rule: monthly(onDay: 2), calendar: calendar, in: context)
            try context.save()
            try model.refresh()
            let bill = model.bills[0]

            for month in 2...6 {
                try await model.markPaid(BillOccurrence(bill: bill, dueDate: makeDate(year: 2025, month: month, day: 2), calendar: calendar))
            }

            #expect(bill.nextDisplayDueDate(referenceDate: today, calendar: calendar) == makeDate(year: 2025, month: 7, day: 2))
        }
    }

    // MARK: - overdueUnpaidOccurrences (the reschedule warning guard)

    @MainActor
    @Suite("overdueUnpaidOccurrences")
    struct OverdueUnpaidOccurrences {
        @Test func whenRecurringBillHasUnpaidPastOccurrences_thenReturnsAllStrictlyPast() throws {
            let calendar = utcCalendar()
            let today = makeDate(year: 2025, month: 7, day: 1)
            let anchor = makeDate(year: 2025, month: 2, day: 2)
            let (model, context) = try makeModel(referenceDate: today, calendar: calendar)
            _ = makeBill(dueDate: anchor, rule: monthly(onDay: 2), calendar: calendar, in: context)
            try context.save()
            try model.refresh()
            let bill = model.bills[0]

            let overdue = bill.overdueUnpaidOccurrences(asOf: today, calendar: calendar)

            let expected = (2...6).map { makeDate(year: 2025, month: $0, day: 2) }
            #expect(Set(overdue) == Set(expected))
        }

        @Test func whenOccurrenceDueToday_thenNotCountedAsStranded() throws {
            let calendar = utcCalendar()
            let today = makeDate(year: 2025, month: 7, day: 1)
            let anchor = makeDate(year: 2025, month: 4, day: 1)
            let (model, context) = try makeModel(referenceDate: today, calendar: calendar)
            _ = makeBill(dueDate: anchor, rule: monthly(onDay: 1), calendar: calendar, in: context)
            try context.save()
            try model.refresh()
            let bill = model.bills[0]

            let overdue = bill.overdueUnpaidOccurrences(asOf: today, calendar: calendar)

            #expect(overdue.contains(makeDate(year: 2025, month: 7, day: 1)) == false)
            #expect(Set(overdue) == Set((4...6).map { makeDate(year: 2025, month: $0, day: 1) }))
        }

        @Test func whenOverdueOccurrencePartiallyPaid_thenStillCountedAsStranded() async throws {
            let calendar = utcCalendar()
            let today = makeDate(year: 2025, month: 7, day: 1)
            let anchor = makeDate(year: 2025, month: 5, day: 2)
            let (model, context) = try makeModel(referenceDate: today, calendar: calendar)
            _ = makeBill(dueDate: anchor, amount: 100, rule: monthly(onDay: 2), calendar: calendar, in: context)
            try context.save()
            try model.refresh()
            let bill = model.bills[0]

            // Partial payment on the May 2 overdue occurrence.
            try await model.markPaid(
                BillOccurrence(bill: bill, dueDate: makeDate(year: 2025, month: 5, day: 2), calendar: calendar),
                amount: 40
            )

            let overdue = bill.overdueUnpaidOccurrences(asOf: today, calendar: calendar)
            #expect(overdue.contains(makeDate(year: 2025, month: 5, day: 2)))
            #expect(overdue.contains(makeDate(year: 2025, month: 6, day: 2)))
        }

        @Test func whenAllPastPaid_thenNothingStranded() async throws {
            let calendar = utcCalendar()
            let today = makeDate(year: 2025, month: 7, day: 1)
            let anchor = makeDate(year: 2025, month: 2, day: 2)
            let (model, context) = try makeModel(referenceDate: today, calendar: calendar)
            _ = makeBill(dueDate: anchor, amount: 100, rule: monthly(onDay: 2), calendar: calendar, in: context)
            try context.save()
            try model.refresh()
            let bill = model.bills[0]

            for month in 2...6 {
                try await model.markPaid(BillOccurrence(bill: bill, dueDate: makeDate(year: 2025, month: month, day: 2), calendar: calendar))
            }

            #expect(bill.overdueUnpaidOccurrences(asOf: today, calendar: calendar).isEmpty)
        }
    }

    // T2 — a metadata-only edit (name/amount/etc. changed, schedule untouched) must leave the recurrence
    // anchor and day-of-month intact — the invariant the 2-case save relies on.
    @MainActor
    @Suite("metadata-only edit preserves anchor")
    struct MetadataOnlyPreservation {
        @Test func whenMetadataOnlyUpdate_thenAnchorAndDayOfMonthUnchanged() async throws {
            let calendar = utcCalendar()
            let today = makeDate(year: 2025, month: 7, day: 1)
            let anchor = makeDate(year: 2025, month: 1, day: 31)   // day-31 rule
            let (model, context) = try makeModel(referenceDate: today, calendar: calendar)
            _ = makeBill(dueDate: anchor, rule: RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 31), calendar: calendar, in: context)
            try context.save()
            try model.refresh()
            let bill = model.bills[0]

            // Mirror performEdit's metadata-only branch: change a field, leave dueDate + rule untouched.
            let preEdit = BillSnapshot(bill: bill)
            bill.name = "Renamed"
            try await model.updateBill(bill, preEditSnapshot: preEdit)

            #expect(bill.dueDate == anchor)
            #expect(bill.recurrenceRule?.dayOfMonth == 31)
        }
    }
}

// MARK: - BillEditReschedule.resolve (the 2-case save decision)

@MainActor
@Suite("BillEditReschedule.resolve")
struct BillEditRescheduleTests {
    private let calendar = utcCalendar()

    @Test func whenNothingChanged_thenMetadataOnly() {
        let seed = makeDate(year: 2025, month: 7, day: 2)
        let rule = RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 2)
        let outcome = BillEditReschedule.resolve(
            seededDueDate: seed,
            editedDueDate: seed,
            originalRule: RecurrenceRuleSnapshot(rule: rule),
            candidateRule: RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 2),
            calendar: calendar
        )
        #expect(outcome.isScheduleChange == false)
    }

    @Test func whenDayOfMonthIs31AndOnlyMetadataChanged_thenMetadataOnlyPreservesRule() {
        // Day-31 rule; the picker's on-appear sync clamped the draft to day 28 (Feb),
        // and the user did NOT move the date. Must stay metadata-only so the stored
        // day-31 rule is preserved untouched.
        let seed = makeDate(year: 2025, month: 2, day: 28)
        let original = RecurrenceRuleSnapshot(rule: RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 31))
        let clampedCandidate = RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 28)

        let outcome = BillEditReschedule.resolve(
            seededDueDate: seed,
            editedDueDate: seed,
            originalRule: original,
            candidateRule: clampedCandidate,
            calendar: calendar
        )

        #expect(outcome.isScheduleChange == false)   // rule left untouched → day-31 preserved
    }

    @Test func whenDateChanged_thenScheduleChangeReAnchoredToNewDate() {
        let seed = makeDate(year: 2025, month: 7, day: 2)
        let edited = makeDate(year: 2025, month: 7, day: 15)
        let rule = RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 2)

        let outcome = BillEditReschedule.resolve(
            seededDueDate: seed,
            editedDueDate: edited,
            originalRule: RecurrenceRuleSnapshot(rule: rule),
            candidateRule: RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 15),
            calendar: calendar
        )

        #expect(outcome.isScheduleChange)
        #expect(outcome.newDueDate == calendar.startOfDay(for: edited))
        #expect(outcome.newRule?.dayOfMonth == 15)
    }

    @Test func whenPatternChangedButDateUntouched_thenScheduleChangeAnchoredToDisplayedDate() {
        // Changing the recurrence pattern with the date untouched must re-anchor forward
        // to the DISPLAYED date, never leave the old anchor (which would project the new
        // schedule retroactively).
        let seed = makeDate(year: 2025, month: 7, day: 2)
        let original = RecurrenceRuleSnapshot(rule: RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 2))
        let weeklyCandidate = RecurrenceRule(pattern: .weekly, frequency: 1, dayOfWeek: .monday)

        let outcome = BillEditReschedule.resolve(
            seededDueDate: seed,
            editedDueDate: seed,
            originalRule: original,
            candidateRule: weeklyCandidate,
            calendar: calendar
        )

        #expect(outcome.isScheduleChange)
        #expect(outcome.newDueDate == calendar.startOfDay(for: seed))
        #expect(outcome.newRule?.pattern == .weekly)
    }

    @Test func whenNonRecurringDateChanged_thenScheduleChange() {
        let seed = makeDate(year: 2025, month: 3, day: 10)
        let edited = makeDate(year: 2025, month: 4, day: 20)
        let outcome = BillEditReschedule.resolve(
            seededDueDate: seed,
            editedDueDate: edited,
            originalRule: nil,
            candidateRule: nil,
            calendar: calendar
        )
        #expect(outcome.isScheduleChange)
        #expect(outcome.newDueDate == calendar.startOfDay(for: edited))
        #expect(outcome.newRule == nil)
    }

    // T1 — removing recurrence (Repeat -> Never) converts to a one-time bill on the displayed date.
    @Test func whenRecurrenceRemovedAndDateUntouched_thenScheduleChangeClearsRule() {
        let seed = makeDate(year: 2025, month: 7, day: 2)
        let original = RecurrenceRuleSnapshot(rule: RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 2))
        let outcome = BillEditReschedule.resolve(
            seededDueDate: seed,
            editedDueDate: seed,
            originalRule: original,
            candidateRule: nil,
            calendar: calendar
        )
        #expect(outcome.isScheduleChange)
        #expect(outcome.newDueDate == calendar.startOfDay(for: seed))
        #expect(outcome.newRule == nil)
    }

    // Regression: the warning body must be rendered text, never raw grammar-agreement markup.
    @Test func whenOneStrandedDate_thenMessageIsSingularWithNoRawMarkup() {
        let message = BillEditReschedule.rescheduleWarningMessage(for: [makeDate(year: 2025, month: 7, day: 2)])
        #expect(message.contains("^[") == false)
        #expect(message.contains("inflect") == false)
        #expect(message.contains("1 unpaid past bill "))   // singular, note trailing space (not "bills")
        #expect(message.contains("overdue list and badge"))
    }

    @Test func whenMultipleStrandedDates_thenMessageIsPluralWithNoRawMarkup() {
        let dates = [
            makeDate(year: 2025, month: 5, day: 2),
            makeDate(year: 2025, month: 6, day: 2),
            makeDate(year: 2025, month: 7, day: 2)
        ]
        let message = BillEditReschedule.rescheduleWarningMessage(for: dates)
        #expect(message.contains("^[") == false)
        #expect(message.contains("3 unpaid past bills"))
    }

    @Test func whenMoreThanThreeStrandedDates_thenListIsCappedWithMore() {
        let dates = (2...7).map { makeDate(year: 2025, month: $0, day: 2) }   // 6 dates
        let message = BillEditReschedule.rescheduleWarningMessage(for: dates)
        #expect(message.contains("^[") == false)
        #expect(message.contains("6 unpaid past bills"))
        #expect(message.contains("more"))   // capped to 3 shown + "N more"
    }

    // T4 — documented short-month edge (SF1): a structural edit on a day-31 rule whose seed is a clamped
    // short-month date re-anchors to the displayed (clamped) day rather than preserving 31.
    @Test func whenDay31StructuralEditWithClampedSeed_thenAdoptsDisplayedDay() {
        let seed = makeDate(year: 2025, month: 2, day: 28)   // day-31 rule, next occurrence clamped to Feb 28
        let original = RecurrenceRuleSnapshot(rule: RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 31))
        let candidate = RecurrenceRule(pattern: .monthly, frequency: 2, dayOfMonth: 28) // freq changed; day clamped by picker
        let outcome = BillEditReschedule.resolve(
            seededDueDate: seed,
            editedDueDate: seed,
            originalRule: original,
            candidateRule: candidate,
            calendar: calendar
        )
        #expect(outcome.isScheduleChange)
        #expect(outcome.newRule?.frequency == 2)
        #expect(outcome.newRule?.dayOfMonth == 28)   // accepted trade-off: adopts displayed clamped day
    }
}

// MARK: - RecurrenceRuleSnapshot.structurallyDiffer (recurrence-change detection)

@MainActor
@Suite("RecurrenceRuleSnapshot.structurallyDiffer")
struct RecurrenceStructuralDiffTests {
    @Test func whenBothNil_thenNoDifference() {
        #expect(RecurrenceRuleSnapshot.structurallyDiffer(nil, nil) == false)
    }

    @Test func whenOneNil_thenDiffers() {
        let rule = RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 2)
        #expect(RecurrenceRuleSnapshot.structurallyDiffer(nil, rule))
        #expect(RecurrenceRuleSnapshot.structurallyDiffer(RecurrenceRuleSnapshot(rule: rule), nil))
    }

    @Test func whenOnlyDayOfMonthDiffers_thenNotStructuralDifference() {
        // A day change rides the date proxy — it must NOT read as a structural recurrence change.
        let original = RecurrenceRuleSnapshot(rule: RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 2))
        let dayChanged = RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 15)
        #expect(RecurrenceRuleSnapshot.structurallyDiffer(original, dayChanged) == false)
    }

    @Test func whenPatternChanges_thenDiffers() {
        let original = RecurrenceRuleSnapshot(rule: RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 2))
        let weekly = RecurrenceRule(pattern: .weekly, frequency: 1, dayOfWeek: .monday)
        #expect(RecurrenceRuleSnapshot.structurallyDiffer(original, weekly))
    }

    @Test func whenFrequencyChanges_thenDiffers() {
        let original = RecurrenceRuleSnapshot(rule: RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 2))
        let everyTwoMonths = RecurrenceRule(pattern: .monthly, frequency: 2, dayOfMonth: 2)
        #expect(RecurrenceRuleSnapshot.structurallyDiffer(original, everyTwoMonths))
    }

    // T3 — moving only the end date (same .endDate condition) is a structural change.
    @Test func whenOnlyEndDateDiffers_thenDiffers() {
        let original = RecurrenceRuleSnapshot(rule: RecurrenceRule(
            pattern: .monthly, frequency: 1, dayOfMonth: 2,
            endConditionType: .endDate, endDate: makeDate(year: 2026, month: 1, day: 2)
        ))
        let laterEnd = RecurrenceRule(
            pattern: .monthly, frequency: 1, dayOfMonth: 2,
            endConditionType: .endDate, endDate: makeDate(year: 2027, month: 1, day: 2)
        )
        #expect(RecurrenceRuleSnapshot.structurallyDiffer(original, laterEnd))
    }
}

// MARK: - Factories & helpers

@MainActor
private func makeModel(referenceDate: Date, calendar: Calendar) throws -> (BillsModel, ModelContext) {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Bill.self,
        PaymentEntry.self,
        IssuedOccurrence.self,
        RecurrenceRule.self,
        Income.self,
        IncomeOccurrence.self,
        configurations: config
    )
    let context = ModelContext(container)
    let model = BillsModel(
        modelContext: context,
        calendar: calendar,
        currentDate: { referenceDate },
        notificationCoordinator: NotificationCoordinatorSpy(),
        notificationPreferences: NotificationPreferencesStub()
    )
    return (model, context)
}

@MainActor
@discardableResult
private func makeBill(
    dueDate: Date,
    amount: Decimal = 100,
    rule: RecurrenceRule?,
    calendar: Calendar,
    in context: ModelContext
) -> Bill {
    let bill = Bill(name: "Streaming", amount: amount, dueDate: dueDate, calendar: calendar)
    bill.recurrenceRule = rule
    context.insert(bill)
    return bill
}

@MainActor
private func monthly(onDay day: Int) -> RecurrenceRule {
    RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: day)
}

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.locale = Locale(identifier: "en_US")
    return calendar
}

private func makeDate(year: Int = 2025, month: Int = 1, day: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.locale = Locale(identifier: "en_US")
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return calendar.date(from: components)!
}
