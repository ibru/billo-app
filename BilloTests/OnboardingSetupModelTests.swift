//  Created by Jiri Urbasek on 7/10/26.

import Foundation
import SwiftData
import Testing
@testable import Billo

@MainActor
@Suite("OnboardingSetupModel")
struct OnboardingSetupModelTests {
    @Suite("drafting bills")
    @MainActor
    struct DraftingBills {
        @Test func whenSavingBillForNewPreset_thenDraftIsAdded() {
            let sut = makeSUT()

            sut.saveBill(preset: rentPreset, amount: 1500, dueDayOfMonth: 1, recurrence: .monthly)

            #expect(sut.billCount == 1)
            #expect(sut.billDraft(for: rentPreset.id)?.amount == 1500)
        }

        @Test func whenSavingBillForAlreadyDraftedPreset_thenDraftIsReplacedNotDuplicated() {
            let sut = makeSUT()
            sut.saveBill(preset: rentPreset, amount: 1500, dueDayOfMonth: 1, recurrence: .monthly)

            sut.saveBill(preset: rentPreset, amount: 1800, dueDayOfMonth: 5, recurrence: .monthly)

            #expect(sut.billCount == 1)
            #expect(sut.billDraft(for: rentPreset.id)?.amount == 1800)
            #expect(sut.billDraft(for: rentPreset.id)?.dueDayOfMonth == 5)
        }

        @Test func whenRemovingDraftedBill_thenItNoLongerCountsTowardSetup() {
            let sut = makeSUT()
            sut.saveBill(preset: rentPreset, amount: 1500, dueDayOfMonth: 1, recurrence: .monthly)
            sut.saveBill(preset: gymPreset, amount: 30, dueDayOfMonth: 10, recurrence: .monthly)

            sut.removeBill(presetID: rentPreset.id)

            #expect(sut.billCount == 1)
            #expect(sut.billDraft(for: rentPreset.id) == nil)
        }

        @Test func whenEstimatingMonthlyTotal_thenWeeklyBillsAreSpreadAcrossTheYear() {
            let sut = makeSUT()
            sut.saveBill(preset: rentPreset, amount: 1200, dueDayOfMonth: 1, recurrence: .monthly)
            sut.saveBill(preset: gymPreset, amount: 12, dueDayOfMonth: 10, recurrence: .weekly)

            let weeklySpreadMonthly: Decimal = 12 * 52 / 12
            #expect(sut.estimatedMonthlyTotal == 1200 + weeklySpreadMonthly)
        }
    }

    @Suite("drafting income")
    @MainActor
    struct DraftingIncome {
        @Test func whenSettingIncomeWithPaddedName_thenNameIsTrimmed() throws {
            let sut = makeSUT()

            try sut.setIncome(name: "  Salary ", amount: 3000, cadence: .monthly, nextPayday: anyDate)

            #expect(sut.incomeDraft?.name == "Salary")
        }

        @Test func whenSettingIncomeWithEmptyName_thenValidationFails() {
            let sut = makeSUT()

            #expect(throws: IncomeValidationError.emptyName) {
                try sut.setIncome(name: "   ", amount: 3000, cadence: .monthly, nextPayday: anyDate)
            }
        }

        @Test func whenSettingIncomeWithZeroAmount_thenValidationFails() {
            let sut = makeSUT()

            #expect(throws: IncomeValidationError.nonPositiveAmount) {
                try sut.setIncome(name: "Salary", amount: 0, cadence: .monthly, nextPayday: anyDate)
            }
        }

        @Test func whenClearingIncome_thenDraftIsRemoved() throws {
            let sut = makeSUT()
            try sut.setIncome(name: "Salary", amount: 3000, cadence: .monthly, nextPayday: anyDate)

            sut.clearIncome()

            #expect(sut.incomeDraft == nil)
        }
    }

    @Suite("commit")
    @MainActor
    struct Commit {
        @Test func whenCommittingDrafts_thenBillsLandInProductionStoreWithAuthoritativeCurrency() throws {
            let (sut, store) = try makeSUTWithProductionContext(today: march10)
            let context = store.mainContext
            sut.saveBill(preset: rentPreset, amount: 1500, dueDayOfMonth: 1, recurrence: .monthly)
            sut.saveBill(preset: gymPreset, amount: 30, dueDayOfMonth: 15, recurrence: .weekly)

            let result = try sut.commit(into: context, currencyCode: "EUR")

            let bills = try context.fetch(FetchDescriptor<Bill>(sortBy: [SortDescriptor(\.name)]))
            #expect(result?.billCount == 2)
            #expect(bills.map(\.name).sorted() == [gymPreset.name, rentPreset.name].sorted())
            #expect(bills.allSatisfy { $0.currencyCode == "EUR" })
        }

        @Test func whenCommittingMonthlyBill_thenDueDateAndRecurrenceMatchChosenDueDay() throws {
            let (sut, store) = try makeSUTWithProductionContext(today: march10)
            let context = store.mainContext
            sut.saveBill(preset: rentPreset, amount: 1500, dueDayOfMonth: 5, recurrence: .monthly)

            try sut.commit(into: context, currencyCode: "USD")

            let bill = try #require(try context.fetch(FetchDescriptor<Bill>()).first)
            let expectedDueDate = try #require(utcCalendar.date(from: DateComponents(year: 2026, month: 4, day: 5)))
            #expect(bill.dueDate == expectedDueDate)
            #expect(bill.recurrenceRule?.pattern == .monthly)
            #expect(bill.recurrenceRule?.dayOfMonth == 5)
            #expect(bill.categoryIdentifier == .predefined(rentPreset.category))
        }

        @Test func whenCommittingOneTimeBill_thenNoRecurrenceRuleIsCreated() throws {
            let (sut, store) = try makeSUTWithProductionContext(today: march10)
            let context = store.mainContext
            sut.saveBill(preset: gymPreset, amount: 30, dueDayOfMonth: 15, recurrence: .none)

            try sut.commit(into: context, currencyCode: "USD")

            let bill = try #require(try context.fetch(FetchDescriptor<Bill>()).first)
            #expect(bill.recurrenceRule == nil)
        }

        @Test func whenCommittingIncomeDraft_thenIncomeLandsWithCadenceRule() throws {
            let (sut, store) = try makeSUTWithProductionContext(today: march10)
            let context = store.mainContext
            try sut.setIncome(name: "Salary", amount: 3000, cadence: .monthly, nextPayday: march10)

            let result = try sut.commit(into: context, currencyCode: "EUR")

            let income = try #require(try context.fetch(FetchDescriptor<Income>()).first)
            #expect(result?.hasIncome == true)
            #expect(income.name == "Salary")
            #expect(income.currencyCode == "EUR")
            #expect(income.recurrenceRule?.pattern == .monthly)
            #expect(income.recurrenceRule?.dayOfMonth == 10)
        }

        @Test func whenCommittingASecondTime_thenNothingNewIsInsertedAndResultIsNil() throws {
            let (sut, store) = try makeSUTWithProductionContext(today: march10)
            let context = store.mainContext
            sut.saveBill(preset: rentPreset, amount: 1500, dueDayOfMonth: 1, recurrence: .monthly)
            try sut.commit(into: context, currencyCode: "USD")

            let secondResult = try sut.commit(into: context, currencyCode: "USD")

            let bills = try context.fetch(FetchDescriptor<Bill>())
            #expect(secondResult == nil)
            #expect(bills.count == 1)
        }

        @Test func whenCommittingWithNoDrafts_thenCommitSucceedsWithEmptyResult() throws {
            let (sut, store) = try makeSUTWithProductionContext(today: march10)
            let context = store.mainContext

            let result = try sut.commit(into: context, currencyCode: "USD")

            #expect(result?.billCount == 0)
            #expect(result?.hasIncome == false)
        }

        @Test func whenCommittingBiweeklyBill_thenRuleIsWeeklyWithFrequencyTwo() throws {
            let (sut, store) = try makeSUTWithProductionContext(today: march10)
            let context = store.mainContext
            sut.saveBill(preset: gymPreset, amount: 30, dueDayOfMonth: 15, recurrence: .biweekly)

            try sut.commit(into: context, currencyCode: "USD")

            let bill = try #require(try context.fetch(FetchDescriptor<Bill>()).first)
            #expect(bill.recurrenceRule?.pattern == .weekly)
            #expect(bill.recurrenceRule?.frequency == 2)
        }

        @Test func whenCommittingIncomeOnly_thenResultHasIncomeAndZeroBills() throws {
            let (sut, store) = try makeSUTWithProductionContext(today: march10)
            let context = store.mainContext
            try sut.setIncome(name: "Salary", amount: 3000, cadence: .monthly, nextPayday: march10)

            let result = try sut.commit(into: context, currencyCode: "USD")

            let incomes = try context.fetch(FetchDescriptor<Income>())
            #expect(result?.billCount == 0)
            #expect(result?.hasIncome == true)
            #expect(incomes.count == 1)
        }

        @Test func whenSaveFails_thenPreviouslySavedDataSurvivesTheRollback() throws {
            let (sut, store) = try makeSUTWithProductionContext(today: march10)
            let context = store.mainContext
            context.insert(Bill(name: "Existing bill", amount: 50, dueDate: march10))
            try context.save()
            sut.saveBill(preset: rentPreset, amount: 1500, dueDayOfMonth: 1, recurrence: .monthly)
            sut.performSave = { _ in throw makeSaveError() }

            #expect(throws: (any Error).self) {
                try sut.commit(into: context, currencyCode: "USD")
            }

            let bills = try context.fetch(FetchDescriptor<Bill>())
            #expect(bills.map(\.name) == ["Existing bill"], "rollback must only discard the failed commit's inserts")
        }

        @Test func whenSaveFails_thenDraftsSurviveForRetry() throws {
            let (sut, store) = try makeSUTWithProductionContext(today: march10)
            let context = store.mainContext
            sut.saveBill(preset: rentPreset, amount: 1500, dueDayOfMonth: 1, recurrence: .monthly)
            try sut.setIncome(name: "Salary", amount: 3000, cadence: .monthly, nextPayday: march10)
            sut.performSave = { _ in throw makeSaveError() }

            #expect(throws: (any Error).self) {
                try sut.commit(into: context, currencyCode: "USD")
            }

            #expect(sut.billCount == 1)
            #expect(sut.billDraft(for: rentPreset.id)?.amount == 1500)
            #expect(sut.incomeDraft?.name == "Salary")
        }

        @Test func whenSaveFails_thenNothingStaysPendingAndRetryDoesNotDuplicate() throws {
            let (sut, store) = try makeSUTWithProductionContext(today: march10)
            let context = store.mainContext
            sut.saveBill(preset: rentPreset, amount: 1500, dueDayOfMonth: 1, recurrence: .monthly)
            sut.saveBill(preset: gymPreset, amount: 30, dueDayOfMonth: 15, recurrence: .weekly)
            sut.performSave = { _ in throw makeSaveError() }

            #expect(throws: (any Error).self) {
                try sut.commit(into: context, currencyCode: "USD")
            }

            let billsAfterFailure = try context.fetch(FetchDescriptor<Bill>())
            #expect(billsAfterFailure.isEmpty, "failed commit must roll back its pending inserts")
            #expect(sut.didCommit == false)

            sut.performSave = { try $0.save() }
            let retryResult = try sut.commit(into: context, currencyCode: "USD")

            let billsAfterRetry = try context.fetch(FetchDescriptor<Bill>())
            #expect(retryResult?.billCount == 2)
            #expect(billsAfterRetry.count == 2, "retry after a failed save must not duplicate bills")
        }
    }
}

// MARK: - makeSUT & Factories

private let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
    return calendar
}()

private let march10: Date = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10)) ?? Date()
private let anyDate = march10

private let rentPreset = OnboardingBillPreset.all.first { $0.id == "rent" } ?? OnboardingBillPreset.all[0]
private let gymPreset = OnboardingBillPreset.all.first { $0.id == "gym" } ?? OnboardingBillPreset.all[1]

@MainActor
private func makeSUT(today: Date = march10) -> OnboardingSetupModel {
    OnboardingSetupModel(calendar: utcCalendar, currentDate: { today })
}

private func makeSaveError() -> NSError {
    NSError(domain: "tests.onboarding.save", code: Int.random(in: 1...9999))
}

/// Returns the container (not just its context) so the store stays alive for
/// the duration of the test — a bare `ModelContext` whose container has been
/// deallocated crashes on save.
@MainActor
private func makeSUTWithProductionContext(today: Date) throws -> (OnboardingSetupModel, ModelContainer) {
    let schema = Schema([
        Bill.self,
        PaymentEntry.self,
        IssuedOccurrence.self,
        RecurrenceRule.self,
        Income.self,
        IncomeOccurrence.self,
        CustomCategory.self,
        AppSettings.self
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    return (makeSUT(today: today), container)
}
