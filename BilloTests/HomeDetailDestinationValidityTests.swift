//  Created by Jiri Urbasek on 07/16/26.

import Foundation
import SwiftData
import Testing
@testable import Billo

@MainActor
@Suite("HomeDetailDestination.isValid(in:)")
struct HomeDetailDestinationValidityTests {
    @Test
    func whenBillExists_thenBillDestinationIsValid() throws {
        let (bill, context) = try makeStoredBill()

        let destination = HomeDetailDestination.bill(bill.persistentModelID)

        #expect(destination.isValid(in: context))
    }

    @Test
    func whenBillInsertedButNotYetSaved_thenBillDestinationIsValid() throws {
        let context = try makeContext()
        let bill = Bill(name: "Internet", amount: 50, dueDate: Date())
        context.insert(bill)

        let destination = HomeDetailDestination.bill(bill.persistentModelID)

        #expect(destination.isValid(in: context))
    }

    @Test
    func whenBillDeletedAndSaved_thenBillDestinationIsInvalid() throws {
        let (bill, context) = try makeStoredBill()
        let destination = HomeDetailDestination.bill(bill.persistentModelID)

        context.delete(bill)
        try context.save()

        #expect(destination.isValid(in: context) == false)
    }

    @Test
    func whenBillDeletedButNotYetSaved_thenBillDestinationIsInvalid() throws {
        let (bill, context) = try makeStoredBill()
        let destination = HomeDetailDestination.bill(bill.persistentModelID)

        context.delete(bill)

        #expect(destination.isValid(in: context) == false)
    }

    /// Regression guard for the original crash: `modelContext.model(for:)`
    /// keeps resolving a deleted record to its still-registered zombie
    /// instance (whose property reads trap), so routing must rely on
    /// `isValid(in:)` instead.
    @Test
    func whenBillDeleted_thenDestinationInvalidEvenThoughModelForStillResolves() throws {
        let (bill, context) = try makeStoredBill()
        let billID = bill.persistentModelID
        let destination = HomeDetailDestination.bill(billID)

        context.delete(bill)
        try context.save()

        _ = try #require(
            context.model(for: billID) as? Bill,
            "premise: model(for:) still resolves deleted records to zombie instances"
        )
        #expect(destination.isValid(in: context) == false)
    }

    @Test
    func whenIncomeDeletedAndSaved_thenIncomeDestinationIsInvalid() throws {
        let (income, context) = try makeStoredIncome()
        let destination = HomeDetailDestination.income(income.persistentModelID)

        context.delete(income)
        try context.save()

        #expect(destination.isValid(in: context) == false)
    }

    @Test
    func whenIssuedOccurrenceDeletedAndSaved_thenOccurrenceDestinationIsInvalid() throws {
        let (occurrence, context) = try makeStoredIssuedOccurrence()
        let destination = HomeDetailDestination.occurrence(occurrence.persistentModelID)
        #expect(destination.isValid(in: context))

        context.delete(occurrence)
        try context.save()

        #expect(destination.isValid(in: context) == false)
    }

    @Test
    func whenPaymentDeletedAndSaved_thenPaymentDestinationIsInvalid() throws {
        let (payment, context) = try makeStoredPayment()
        let destination = HomeDetailDestination.payment(payment.persistentModelID)
        #expect(destination.isValid(in: context))

        context.delete(payment)
        try context.save()

        #expect(destination.isValid(in: context) == false)
    }

    /// Income occurrence "deletion" is a soft-skip: the row stays in the store
    /// with `isExcluded == true` and is invisible to all view-layer reads —
    /// navigation must treat it as gone even though the record still exists.
    @Test
    func whenIncomeOccurrenceExcluded_thenIncomeOccurrenceDestinationIsInvalid() throws {
        let (occurrence, context) = try makeStoredIncomeOccurrence()
        let destination = HomeDetailDestination.incomeOccurrence(occurrence.persistentModelID)
        #expect(destination.isValid(in: context))

        occurrence.isExcluded = true
        try context.save()

        #expect(destination.isValid(in: context) == false)
    }

    @Test
    func whenIncomeOccurrenceHardDeletedAndSaved_thenIncomeOccurrenceDestinationIsInvalid() throws {
        let (occurrence, context) = try makeStoredIncomeOccurrence()
        let destination = HomeDetailDestination.incomeOccurrence(occurrence.persistentModelID)

        context.delete(occurrence)
        try context.save()

        #expect(destination.isValid(in: context) == false)
    }

    @Test
    func whenStaticDestinations_thenAlwaysValid() throws {
        let context = try makeContext()

        let staticDestinations: [HomeDetailDestination] = [
            .paymentHistory, .incomeList, .charts, .dataExport
        ]

        #expect(staticDestinations.allSatisfy { $0.isValid(in: context) })
    }
}

@Suite("HomeDetailDestination.prunedNavigation")
struct HomeDetailDestinationPruningTests {
    // Validity is injected as a closure, so the pruning decision never
    // dereferences a store — any distinct destinations work as stand-ins.
    private let deletedBill = HomeDetailDestination.charts
    private let liveIncome = HomeDetailDestination.incomeList

    @Test
    func whenSelectionInvalid_thenSelectionAndPathClear() {
        let pruned = HomeDetailDestination.prunedNavigation(
            selection: deletedBill,
            path: [liveIncome, .paymentHistory],
            isValid: { $0 != deletedBill }
        )

        #expect(pruned.selection == nil && pruned.path.isEmpty)
    }

    @Test
    func whenSelectionValidAndPathValid_thenNothingChanges() {
        let pruned = HomeDetailDestination.prunedNavigation(
            selection: liveIncome,
            path: [deletedBill, .paymentHistory],
            isValid: { _ in true }
        )

        #expect(pruned.selection == liveIncome && pruned.path == [deletedBill, .paymentHistory])
    }

    /// The path trims from its FIRST invalid element: keeping a later valid
    /// entry would silently reparent it under a different hierarchy.
    @Test
    func whenIntermediatePathEntryInvalid_thenPathTrimsFromFirstInvalidElement() {
        let pruned = HomeDetailDestination.prunedNavigation(
            selection: liveIncome,
            path: [.paymentHistory, deletedBill, liveIncome],
            isValid: { $0 != deletedBill }
        )

        #expect(pruned.selection == liveIncome && pruned.path == [.paymentHistory])
    }

    @Test
    func whenNoSelection_thenOnlyPathIsPruned() {
        let pruned = HomeDetailDestination.prunedNavigation(
            selection: nil,
            path: [deletedBill],
            isValid: { $0 != deletedBill }
        )

        #expect(pruned.selection == nil && pruned.path.isEmpty)
    }

    @Test
    func whenPathIsEmpty_thenNothingChanges() {
        let pruned = HomeDetailDestination.prunedNavigation(
            selection: liveIncome,
            path: [],
            isValid: { $0 != deletedBill }
        )

        #expect(pruned.selection == liveIncome && pruned.path.isEmpty)
    }

    @Test
    func whenPathHasRepeatedInvalidEntries_thenPathTrimsFromFirstInvalidElement() {
        let pruned = HomeDetailDestination.prunedNavigation(
            selection: liveIncome,
            path: [deletedBill, .paymentHistory, deletedBill],
            isValid: { $0 != deletedBill }
        )

        #expect(pruned.selection == liveIncome && pruned.path.isEmpty)
    }
}

// MARK: - Factories

@MainActor
private func makeContext() throws -> ModelContext {
    let schema = Schema([
        Bill.self,
        PaymentEntry.self,
        IssuedOccurrence.self,
        RecurrenceRule.self,
        Income.self,
        IncomeOccurrence.self
    ])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    return ModelContext(container)
}

@MainActor
private func makeStoredBill(
    name: String = "Internet",
    amount: Decimal = 50,
    dueDate: Date = Date()
) throws -> (Bill, ModelContext) {
    let context = try makeContext()
    let bill = Bill(name: name, amount: amount, dueDate: dueDate)
    context.insert(bill)
    try context.save()
    return (bill, context)
}

@MainActor
private func makeStoredIncome(
    name: String = "Salary",
    amount: Decimal = 3000,
    startDate: Date = Date()
) throws -> (Income, ModelContext) {
    let context = try makeContext()
    let income = Income(name: name, amount: amount, startDate: startDate)
    context.insert(income)
    try context.save()
    return (income, context)
}

@MainActor
private func makeStoredIssuedOccurrence(dueDate: Date = Date()) throws -> (IssuedOccurrence, ModelContext) {
    let (bill, context) = try makeStoredBill(dueDate: dueDate)
    let occurrence = makeIssuedOccurrence(for: bill, dueDate: dueDate, in: context)
    try context.save()
    return (occurrence, context)
}

@MainActor
private func makeStoredPayment(amount: Decimal = 50, paidDate: Date = Date()) throws -> (PaymentEntry, ModelContext) {
    let (bill, context) = try makeStoredBill(amount: amount, dueDate: paidDate)
    let payment = makePaymentEntry(
        amount: amount,
        datePaid: paidDate,
        occurrenceDate: paidDate,
        bill: bill,
        in: context
    )
    try context.save()
    return (payment, context)
}

@MainActor
private func makeStoredIncomeOccurrence(date: Date = Date()) throws -> (IncomeOccurrence, ModelContext) {
    let (income, context) = try makeStoredIncome(startDate: date)
    let occurrence = IncomeOccurrence(
        occurrenceKey: "test-occurrence-key",
        date: date,
        incomeName: income.name,
        incomeAmount: income.amount,
        incomeCurrencyCode: income.currencyCode,
        income: income
    )
    context.insert(occurrence)
    try context.save()
    return (occurrence, context)
}
