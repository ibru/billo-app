//  Created by Jiri Urbasek on 7/10/26.

import Foundation
import SwiftData

/// Holds the bills and income a user drafts during onboarding quick setup.
/// Drafts are plain value types — nothing touches SwiftData (or CloudKit)
/// until `commit(into:currencyCode:)` builds real models in the production
/// context in a single save. Quitting mid-flow or the returning-user skip
/// simply discards this object.
@MainActor @Observable
final class OnboardingSetupModel {
    struct BillDraft: Equatable {
        let preset: OnboardingBillPreset
        var amount: Decimal
        var dueDayOfMonth: Int
        var recurrence: RecurrencePreset
    }

    struct IncomeDraft: Equatable {
        var name: String
        var amount: Decimal
        var cadence: RecurrencePreset
        var nextPayday: Date
    }

    struct CommitResult {
        let billCount: Int
        let hasIncome: Bool
    }

    private(set) var billDrafts: [BillDraft] = []
    private(set) var incomeDraft: IncomeDraft?
    private(set) var didCommit = false

    private let calendar: Calendar
    private let currentDate: () -> Date

    /// Seam for tests to simulate a failing save — SwiftData offers no way to
    /// make `save()` throw deterministically, and the rollback-on-failure
    /// behavior (see `commit`) needs a regression test. Ignored by observation:
    /// it's plumbing, not UI state.
    @ObservationIgnored var performSave: (ModelContext) throws -> Void = { try $0.save() }

    init(calendar: Calendar = .current, currentDate: @escaping () -> Date = { Date() }) {
        self.calendar = calendar
        self.currentDate = currentDate
    }

    // MARK: - Bills

    var billCount: Int { billDrafts.count }

    var estimatedMonthlyTotal: Decimal {
        billDrafts.reduce(0) { total, draft in
            total + OnboardingBillPreset.monthlyEquivalent(amount: draft.amount, recurrence: draft.recurrence)
        }
    }

    func billDraft(for presetID: String) -> BillDraft? {
        billDrafts.first { $0.preset.id == presetID }
    }

    /// The due date a draft with this due day would get at commit — single
    /// source of truth for both the adjust sheet's "First due" footer and
    /// `commit`, using the same injected clock/calendar.
    func firstDueDate(forDayOfMonth dayOfMonth: Int) -> Date {
        OnboardingBillPreset.nextDueDate(dayOfMonth: dayOfMonth, from: currentDate(), calendar: calendar)
    }

    /// Adds a new draft, or replaces the existing draft for the same preset
    /// (the adjust sheet saves through this in both add and edit mode).
    func saveBill(
        preset: OnboardingBillPreset,
        amount: Decimal,
        dueDayOfMonth: Int,
        recurrence: RecurrencePreset
    ) {
        let draft = BillDraft(
            preset: preset,
            amount: amount,
            dueDayOfMonth: dueDayOfMonth,
            recurrence: recurrence
        )
        if let index = billDrafts.firstIndex(where: { $0.preset.id == preset.id }) {
            billDrafts[index] = draft
        } else {
            billDrafts.append(draft)
        }
    }

    func removeBill(presetID: String) {
        billDrafts.removeAll { $0.preset.id == presetID }
    }

    // MARK: - Income

    /// Validates through `Income.validate` so the draft can't hold values the
    /// commit-time `Income.create` would reject.
    func setIncome(name: String, amount: Decimal, cadence: RecurrencePreset, nextPayday: Date) throws {
        let validated = try Income.validate(
            name: name,
            amount: amount,
            startDate: nextPayday,
            recurrenceRule: nil
        )
        incomeDraft = IncomeDraft(
            name: validated.name,
            amount: validated.amount,
            cadence: cadence,
            nextPayday: validated.startDate
        )
    }

    func clearIncome() {
        incomeDraft = nil
    }

    // MARK: - Commit

    /// Builds real `Bill`/`Income` models from the drafts and saves them into
    /// `productionContext` in one batch. Returns nil (inserting nothing) when
    /// already committed — the guard against double-commit. `currencyCode` is
    /// applied to every entity as the authoritative currency.
    ///
    /// This is a deliberate bulk-import path that bypasses
    /// `BillsModel.addBill/addIncome` (their per-item save/refresh/notification
    /// side effects don't fit a batch). The contract: insert + single save
    /// here; the caller runs `billsModel.refresh()` (which also materializes
    /// income occurrences) and fires the creation analytics.
    ///
    /// On a failed save the context is rolled back before rethrowing —
    /// otherwise the inserted models would stay pending in the autosaving main
    /// context and a retry would insert a duplicate set. Note `rollback()`
    /// discards ALL unsaved changes in the shared main context; that is safe
    /// here only because every earlier onboarding write saves explicitly
    /// (currency via `AppSettingsModel.setCurrency`) — keep it that way.
    @discardableResult
    func commit(into productionContext: ModelContext, currencyCode: String) throws -> CommitResult? {
        guard !didCommit else { return nil }

        let today = currentDate()

        do {
            for draft in billDrafts {
                let dueDate = OnboardingBillPreset.nextDueDate(
                    dayOfMonth: draft.dueDayOfMonth,
                    from: today,
                    calendar: calendar
                )
                let bill = Bill(
                    name: draft.preset.name,
                    amount: draft.amount,
                    currencyCode: currencyCode,
                    dueDate: dueDate,
                    categoryIdentifier: .predefined(draft.preset.category),
                    recurrenceRule: recurrenceRule(for: draft.recurrence, dueDate: dueDate, dueDayOfMonth: draft.dueDayOfMonth),
                    calendar: calendar
                )
                productionContext.insert(bill)
            }

            if let incomeDraft {
                let income = try Income.create(
                    name: incomeDraft.name,
                    amount: incomeDraft.amount,
                    currencyCode: currencyCode,
                    startDate: incomeDraft.nextPayday,
                    recurrenceRule: recurrenceRule(
                        for: incomeDraft.cadence,
                        dueDate: incomeDraft.nextPayday,
                        dueDayOfMonth: calendar.component(.day, from: incomeDraft.nextPayday)
                    ),
                    calendar: calendar
                )
                productionContext.insert(income)
            }

            try performSave(productionContext)
        } catch {
            productionContext.rollback()
            throw error
        }

        didCommit = true
        return CommitResult(billCount: billDrafts.count, hasIncome: incomeDraft != nil)
    }

    private func recurrenceRule(
        for preset: RecurrencePreset,
        dueDate: Date,
        dueDayOfMonth: Int
    ) -> RecurrenceRule? {
        let weekday = Weekday.fromCalendarWeekday(calendar.component(.weekday, from: dueDate)) ?? .monday
        return preset.buildRecurrenceRule(
            intervalType: .monthly,
            frequency: 1,
            dayOfWeek: weekday,
            dayOfMonth: dueDayOfMonth
        )
    }
}
