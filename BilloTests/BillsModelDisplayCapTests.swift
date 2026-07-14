//  Created by Jiri Urbasek on 7/13/26.

import Testing
import SwiftData
import Foundation
@testable import Billo

/// Display-time free-tier caps: over-limit bills/incomes are hidden (never
/// deleted) for non-Pro users; the soonest-due bills claim the visible slots.
@Suite("BillsModel display cap")
struct BillsModelDisplayCapTests {

    @MainActor
    @Suite("bill cap")
    struct BillCap {
        @Test func whenBillCountExceedsLimitAndNotPro_thenPublishesLimitBillsAndHiddenCount() throws {
            let (sut, _, _, _) = try makeSUT(billCount: 20, isPro: false)

            try sut.refresh()

            #expect(sut.bills.count == FreeTierLimits.billLimit)
            #expect(sut.hiddenBillCount == 5)
            #expect(sut.totalBillCount == 20)
        }

        @Test func whenBillCountExceedsLimitAndPro_thenPublishesAllBills() throws {
            let (sut, _, _, _) = try makeSUT(billCount: 20, isPro: true)

            try sut.refresh()

            #expect(sut.bills.count == 20)
            #expect(sut.hiddenBillCount == 0)
            #expect(sut.totalBillCount == 20)
        }

        @Test func whenBillCountWithinLimitAndNotPro_thenPublishesAllBills() throws {
            let (sut, _, _, _) = try makeSUT(billCount: 15, isPro: false)

            try sut.refresh()

            #expect(sut.bills.count == 15)
            #expect(sut.hiddenBillCount == 0)
        }

        @Test func whenOverLimit_thenSoonestDueBillsAreVisible() throws {
            // 15 bills due within days of the reference date + one due in 60
            // days. The far-future bill must lose the slot race.
            let (sut, _, context, _) = try makeSUT(billCount: 15, isPro: false)
            insertBill(named: "Far Future", dueInDays: 60, in: context)
            try context.save()

            try sut.refresh()

            #expect(sut.bills.count == FreeTierLimits.billLimit)
            #expect(sut.hiddenBillCount == 1)
            #expect(sut.bills.map(\.name).contains("Far Future") == false)
        }

        @Test func whenOverLimit_thenOverdueBillVisibleAndFarFutureHidden() throws {
            let (sut, _, context, _) = try makeSUT(billCount: 15, isPro: false)
            insertBill(named: "Overdue", dueInDays: -10, in: context)
            try context.save()

            try sut.refresh()

            // Overdue is the soonest unpaid date → it takes a slot; the
            // latest-due of the seeded bills drops out instead.
            #expect(sut.bills.map(\.name).contains("Overdue"))
            #expect(sut.hiddenBillCount == 1)
            #expect(sut.bills.map(\.name).contains("Bill 15") == false)
        }

        @Test func whenOverLimit_thenFullyPaidOneTimeBillRanksAfterUnpaidBills() async throws {
            // A dead (fully paid, one-time) bill must never consume a free
            // slot ahead of a live one, even though its due date is earliest.
            let (sut, _, context, _) = try makeSUT(billCount: 15, isPro: false)
            let paidBill = insertBill(named: "Paid Off", dueInDays: -30, in: context)
            try context.save()
            try sut.refresh()
            let occurrence = BillOccurrence(bill: paidBill, dueDate: paidBill.dueDate)
            try await sut.markPaid(occurrence, source: .sheet)

            #expect(sut.bills.map(\.name).contains("Paid Off") == false)
            #expect(sut.hiddenBillCount == 1)
            #expect(sut.bills.count == FreeTierLimits.billLimit)
        }

        @Test func whenBillsShareNextUnpaidDate_thenTiebreakIsCreatedDateThenStableID() throws {
            // 16 bills all due the same day and sharing the anchor dueDate:
            // the ranking must fall through to createdDate (earlier wins),
            // then stableID — pinning the cross-launch order contract.
            let (_, _, context, _) = try makeSUT(billCount: 0, isPro: false)
            let oldest = insertBill(named: "Oldest", dueInDays: 3, stableID: "z-oldest", in: context)
            oldest.createdDate = makeDate(year: 2025, month: 1, day: 1)
            let newest = insertBill(named: "Newest", dueInDays: 3, stableID: "a-newest", in: context)
            newest.createdDate = makeDate(year: 2025, month: 2, day: 1)
            var fillers: [Bill] = []
            for index in 1...14 {
                let filler = insertBill(
                    named: "Filler \(index)",
                    dueInDays: 3,
                    stableID: String(format: "m-filler-%02d", index),
                    in: context
                )
                filler.createdDate = makeDate(year: 2025, month: 1, day: 15)
                fillers.append(filler)
            }
            try context.save()

            let visible = BillsModel.visibleBills(
                from: [newest, oldest] + fillers,
                isPro: false,
                referenceDate: referenceDate,
                calendar: utcCalendar()
            )

            // createdDate beats stableID: "Newest" (alphabetically first ID)
            // still ranks last and is the one hidden.
            let expectedOrder = ["Oldest"] + (1...14).map { "Filler \($0)" }
            #expect(visible.map(\.name) == expectedOrder)
            #expect(visible.map(\.name).contains("Newest") == false)
        }

        @Test func whenBillsShareNextUnpaidDate_thenVisibleSetIsDeterministicAcrossRefreshes() throws {
            // 20 bills all due the same day: ranking must produce the same
            // visible set on every refresh (stable tiebreaks), or rows would
            // shuffle between refreshes.
            let (sut, _, context, _) = try makeSUT(billCount: 0, isPro: false)
            for index in 1...20 {
                insertBill(named: "Same Day \(index)", dueInDays: 3, in: context)
            }
            try context.save()

            try sut.refresh()
            let firstPass = sut.bills.map(\.stableID)
            try sut.refresh()
            let secondPass = sut.bills.map(\.stableID)

            #expect(firstPass.count == FreeTierLimits.billLimit)
            #expect(firstPass == secondPass)
        }

        @Test func whenOverLimit_thenSectionsContainOnlyVisibleBills() throws {
            let (sut, _, context, _) = try makeSUT(billCount: 15, isPro: false)
            insertBill(named: "Far Future", dueInDays: 60, in: context)
            try context.save()

            try sut.refresh()

            let sectionNames = sut.sections.occurrencesBySection.values
                .flatMap { $0 }
                .map(\.name)
            #expect(sectionNames.contains("Far Future") == false)
        }

        @Test func whenOverLimit_thenNotificationRefreshReceivesOnlyVisibleBills() async throws {
            let (sut, _, context, coordinator) = try makeSUT(billCount: 15, isPro: false)
            insertBill(named: "Far Future", dueInDays: 60, in: context)
            try context.save()
            try sut.refresh()
            #expect(sut.bills.map(\.name).contains("Far Future") == false)

            // Paying off a one-time bill kills it: it drops out of the
            // visible set and the hidden bill is revealed. The notification
            // refresh triggered by the mutation must receive exactly that
            // post-payment visible set.
            let paidBill = sut.bills[0]
            let occurrence = BillOccurrence(bill: paidBill, dueDate: paidBill.dueDate)
            try await sut.markPaid(occurrence, source: .sheet)

            let lastRefreshBills = try #require(coordinator.refreshAllNotificationsCalls.last)
            #expect(lastRefreshBills.count == FreeTierLimits.billLimit)
            #expect(lastRefreshBills.map(\.name).contains(paidBill.name) == false)
            #expect(lastRefreshBills.map(\.name).contains("Far Future"))
        }

        @Test func whenProFlipsToFalseAndRefreshes_thenBillsRetruncate() throws {
            let entitlement = EntitlementStub(isPro: true)
            let (sut, _, _, _) = try makeSUT(billCount: 20, entitlement: entitlement)

            try sut.refresh()
            #expect(sut.bills.count == 20)

            entitlement.isPro = false
            try sut.refresh()

            #expect(sut.bills.count == FreeTierLimits.billLimit)
            #expect(sut.hiddenBillCount == 5)
        }
    }

    @MainActor
    @Suite("income cap")
    struct IncomeCap {
        @Test func whenIncomesExceedLimitAndNotPro_thenPublishesLimitIncomesAndHiddenCount() throws {
            let (sut, _, context, _) = try makeSUT(billCount: 0, isPro: false)
            insertIncomes(named: ["Salary", "Side Gig", "Dividends"], in: context)
            try context.save()

            try sut.refresh()

            #expect(sut.incomes.count == FreeTierLimits.incomeLimit)
            #expect(sut.hiddenIncomeCount == 1)
            #expect(sut.totalIncomeCount == 3)
        }

        @Test func whenIncomesExceedLimitAndPro_thenPublishesAllIncomes() throws {
            let (sut, _, context, _) = try makeSUT(billCount: 0, isPro: true)
            insertIncomes(named: ["Salary", "Side Gig", "Dividends"], in: context)
            try context.save()

            try sut.refresh()

            #expect(sut.incomes.count == 3)
            #expect(sut.hiddenIncomeCount == 0)
        }

        @Test func whenHiddenIncomeExists_thenFutureOccurrenceItemsExcludeIt() throws {
            // The 3rd income (latest startDate) is hidden; its future
            // occurrences must not surface in list/calendar projections.
            let (sut, _, context, _) = try makeSUT(billCount: 0, isPro: false)
            insertMonthlyIncome(named: "Salary", startMonth: 1, amount: 3_000, in: context)
            insertMonthlyIncome(named: "Side Gig", startMonth: 2, amount: 500, in: context)
            insertMonthlyIncome(named: "Dividends", startMonth: 3, amount: 100, in: context)
            try context.save()

            try sut.refresh()

            let futureViews = sut.incomeOccurrenceItems(
                rangeStart: referenceDate,
                rangeEnd: makeDate(year: 2025, month: 8, day: 1)
            )
            #expect(futureViews.isEmpty == false)
            #expect(futureViews.map(\.name).contains("Dividends") == false)
        }

        @Test func whenHiddenIncomeHasUnmaterializedPastOccurrence_thenRefreshStillMaterializesIt() throws {
            // The backfill is data integrity, not display: hidden incomes'
            // past months must still freeze into snapshot rows.
            let (sut, _, context, _) = try makeSUT(billCount: 0, isPro: false)
            insertMonthlyIncome(named: "Salary", startMonth: 1, amount: 3_000, in: context)
            insertMonthlyIncome(named: "Side Gig", startMonth: 1, amount: 500, in: context)
            insertMonthlyIncome(named: "Dividends", startMonth: 1, amount: 100, in: context)
            try context.save()

            try sut.refresh()

            let rows = try context.fetch(FetchDescriptor<IncomeOccurrence>())
            let hiddenIncomeRows = rows.filter { $0.incomeName == "Dividends" }
            // Jan 1 through Apr 1 are past at the Apr 10 reference date.
            #expect(hiddenIncomeRows.count == 4)
        }
    }
}

// MARK: - makeSUT & Factories

private let referenceDate = makeDate(year: 2025, month: 4, day: 10)

/// Mutable entitlement box so tests can flip Pro mid-scenario.
private final class EntitlementStub: @unchecked Sendable {
    var isPro: Bool
    init(isPro: Bool) { self.isPro = isPro }
}

@MainActor
private func makeSUT(
    billCount: Int,
    isPro: Bool = false
) throws -> (BillsModel, [Bill], ModelContext, NotificationCoordinatorSpy) {
    try makeSUT(billCount: billCount, entitlement: EntitlementStub(isPro: isPro))
}

@MainActor
private func makeSUT(
    billCount: Int,
    entitlement: EntitlementStub
) throws -> (BillsModel, [Bill], ModelContext, NotificationCoordinatorSpy) {
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
    let modelContext = ModelContext(container)
    let calendar = utcCalendar()

    var bills: [Bill] = []
    if billCount > 0 {
        bills = (1...billCount).map { index in
            let dueDate = calendar.date(byAdding: .day, value: index, to: referenceDate)!
            let bill = Bill(name: "Bill \(index)", amount: 100, dueDate: dueDate, calendar: calendar)
            modelContext.insert(bill)
            return bill
        }
    }
    try modelContext.save()

    let coordinator = NotificationCoordinatorSpy()
    let sut = BillsModel(
        modelContext: modelContext,
        calendar: calendar,
        currentDate: { referenceDate },
        notificationCoordinator: coordinator,
        notificationPreferences: NotificationPreferencesStub(),
        isPro: { entitlement.isPro }
    )
    return (sut, bills, modelContext, coordinator)
}

@MainActor
@discardableResult
private func insertBill(
    named name: String,
    dueInDays: Int,
    stableID: String? = nil,
    in context: ModelContext
) -> Bill {
    let calendar = utcCalendar()
    let dueDate = calendar.date(byAdding: .day, value: dueInDays, to: referenceDate)!
    let bill = Bill(name: name, amount: 100, dueDate: dueDate, stableID: stableID, calendar: calendar)
    context.insert(bill)
    return bill
}

@MainActor
private func insertIncomes(named names: [String], in context: ModelContext) {
    // startDate ordering mirrors the fetch sort — earlier incomes win slots.
    for (index, name) in names.enumerated() {
        let income = Income(
            name: name,
            amount: 1_000,
            startDate: makeDate(year: 2025, month: 1, day: index + 1),
            recurrenceRule: nil
        )
        context.insert(income)
    }
}

@MainActor
private func insertMonthlyIncome(
    named name: String,
    startMonth: Int,
    amount: Decimal,
    in context: ModelContext
) {
    let income = Income(
        name: name,
        amount: amount,
        startDate: makeDate(year: 2025, month: startMonth, day: 1),
        recurrenceRule: RecurrenceRule(pattern: .monthly, frequency: 1)
    )
    context.insert(income)
}

private func makeDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return utcCalendar().date(from: components)!
}

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.locale = Locale(identifier: "en_US")
    return calendar
}
