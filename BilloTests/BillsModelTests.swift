//  Created by Jiri Urbasek on 11/26/25.

import Testing
import SwiftData
import Foundation
@testable import Billo

@Suite("BillsModel")
struct BillsModelTests {

    @MainActor
    @Suite("refresh")
    struct Refresh {
        @Test func whenRefreshed_thenFetchesBillsFromModelContext() throws {
            let (sut, _, _) = try makeSUT(billCount: 3)

            try sut.refresh()

            #expect(sut.bills.count == 3)
            #expect(sut.bills.map(\.name) == ["Bill 1", "Bill 2", "Bill 3"])
        }

        @Test func whenRefreshed_thenBuildsSections() throws {
            let (sut, _, _) = try makeSUT(billCount: 2)

            try sut.refresh()

            #expect(sut.sections.occurrencesBySection.isEmpty == false)
        }
    }

    @MainActor
    @Suite("markPaid")
    struct MarkPaid {
        @Test func whenMarkingOccurrencePaid_thenCreatesPayment() throws {
            let (sut, bills, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = BillOccurrence(bill: bills[0], dueDate: bills[0].dueDate)

            try sut.markPaid(occurrence)

            #expect(bills[0].payments.count == 1)
            #expect(bills[0].payments[0].amount == bills[0].amount)
        }

        @Test func whenMarkingPaidWithCustomAmount_thenUsesCustomAmount() throws {
            let (sut, bills, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = BillOccurrence(bill: bills[0], dueDate: bills[0].dueDate)
            let customAmount = Decimal(75)

            try sut.markPaid(occurrence, amount: customAmount)

            #expect(bills[0].payments[0].amount == customAmount)
        }

        @Test func whenMarkingPaidWithConfirmation_thenStoresConfirmationNumber() throws {
            let (sut, bills, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = BillOccurrence(bill: bills[0], dueDate: bills[0].dueDate)

            try sut.markPaid(occurrence, confirmationNumber: "CONF123")

            #expect(bills[0].payments[0].confirmationNumber == "CONF123")
        }

        @Test func whenMarkingPaid_thenRefreshesSections() throws {
            let (sut, bills, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = BillOccurrence(bill: bills[0], dueDate: bills[0].dueDate)

            try sut.markPaid(occurrence)

            let allOccurrences = sut.sections.occurrencesBySection.values.flatMap { $0 }
            #expect(allOccurrences.isEmpty)
        }

        @Test func whenMarkingPaid_thenMonthlyTotalsReflectPayment() throws {
            let referenceDate = makeDate(year: 2025, month: 1, day: 20)
            let (sut, bills, _) = try makeSUT(billCount: 1, referenceDate: referenceDate)
            try sut.refresh()

            let occurrence = BillOccurrence(bill: bills[0], dueDate: bills[0].dueDate)

            #expect(sut.sections.monthlyTotals.remaining == bills[0].amount)

            try sut.markPaid(occurrence)

            #expect(sut.sections.monthlyTotals.totalPaid == bills[0].amount)
            #expect(sut.sections.monthlyTotals.remaining == 0)
        }

        @Test func whenMarkingPaid_thenNotifiesPaymentHistory() async throws {
            let spy = PaymentHistoryRefreshingSpy()
            let (sut, bills, _) = try makeSUT(billCount: 1, paymentHistoryRefresher: spy)
            try sut.refresh()

            let occurrence = BillOccurrence(bill: bills[0], dueDate: bills[0].dueDate)

            try sut.markPaid(occurrence)
            await spy.waitForMessages(count: 1)

            let messages = spy.recordedMessages()
            #expect(messages == [.refresh])
        }
    }

    @MainActor
    @Suite("markUnpaid")
    struct MarkUnpaid {
        @Test func whenMarkingOccurrenceUnpaid_thenRemovesPayment() throws {
            let (sut, bills, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = BillOccurrence(bill: bills[0], dueDate: bills[0].dueDate)
            try sut.markPaid(occurrence)

            try sut.markUnpaid(occurrence)

            #expect(bills[0].payments.isEmpty)
        }

        @Test func whenMarkingUnpaid_thenRefreshesSections() throws {
            let (sut, bills, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = BillOccurrence(bill: bills[0], dueDate: bills[0].dueDate)
            try sut.markPaid(occurrence)

            try sut.markUnpaid(occurrence)

            let allOccurrences = sut.sections.occurrencesBySection.values.flatMap { $0 }
            #expect(allOccurrences.count == 1)
        }

        @Test func whenMarkingUnpaid_thenMonthlyTotalsIncrease() throws {
            let referenceDate = makeDate(year: 2025, month: 1, day: 18)
            let (sut, bills, _) = try makeSUT(billCount: 1, referenceDate: referenceDate)
            try sut.refresh()

            let occurrence = BillOccurrence(bill: bills[0], dueDate: bills[0].dueDate)
            try sut.markPaid(occurrence)
            #expect(sut.sections.monthlyTotals.remaining == 0)

            try sut.markUnpaid(occurrence)

            #expect(sut.sections.monthlyTotals.totalPaid == 0)
            #expect(sut.sections.monthlyTotals.remaining == bills[0].amount)
        }

        @Test func whenMarkingUnpaid_thenReloadsPaymentHistoryWindow() async throws {
            let spy = PaymentHistoryRefreshingSpy()
            let (sut, bills, _) = try makeSUT(billCount: 1, paymentHistoryRefresher: spy)
            try sut.refresh()

            let occurrence = BillOccurrence(bill: bills[0], dueDate: bills[0].dueDate)
            try sut.markPaid(occurrence)

            try sut.markUnpaid(occurrence)
            await spy.waitForMessages(count: 2)

            let messages = spy.recordedMessages()
            #expect(messages == [.refresh, .reload])
        }
    }

    @MainActor
    @Suite("deleteBill")
    struct DeleteBill {
        @Test func whenDeletingBill_thenRemovesFromModelContext() throws {
            let (sut, bills, modelContext) = try makeSUT(billCount: 2)
            try sut.refresh()

            try sut.deleteBill(bills[0])

            let descriptor = FetchDescriptor<Bill>()
            let remainingBills = try modelContext.fetch(descriptor)
            #expect(remainingBills.count == 1)
            #expect(remainingBills[0].name == "Bill 2")
        }

        @Test func whenDeletingBill_thenRefreshesList() throws {
            let (sut, bills, _) = try makeSUT(billCount: 2)
            try sut.refresh()

            try sut.deleteBill(bills[0])

            #expect(sut.bills.count == 1)
            #expect(sut.bills[0].name == "Bill 2")
        }
    }
}

// MARK: - makeSUT & Factories

@MainActor
private func makeSUT(
    billCount: Int,
    referenceDate: Date = makeDate(year: 2025, month: 1, day: 15),
    calendar: Calendar = Calendar(identifier: .gregorian),
    paymentHistoryRefresher: PaymentHistoryRefreshing? = nil
) throws -> (BillsModel, [Bill], ModelContext) {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Bill.self, Payment.self, configurations: config)
    let modelContext = ModelContext(container)

    let bills = (1...billCount).map { index in
        let dueDate = calendar.date(byAdding: .day, value: index, to: referenceDate)!

        let bill = Bill(
            name: "Bill \(index)",
            amount: Decimal(100),
            dueDate: dueDate
        )
        modelContext.insert(bill)
        return bill
    }

    try modelContext.save()

    let sut = BillsModel(
        modelContext: modelContext,
        calendar: calendar,
        currentDate: { referenceDate },
        paymentHistoryRefresher: paymentHistoryRefresher
    )

    return (sut, bills, modelContext)
}

private func makeDate(year: Int = 2025, month: Int = 1, day: Int) -> Date {
    let calendar = Calendar.current
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return calendar.date(from: components)!
}

// MARK: - Test Doubles

@MainActor
private final class PaymentHistoryRefreshingSpy: PaymentHistoryRefreshing {
    enum Message: Equatable {
        case refresh
        case reload
    }

    private var recorded: [Message] = []
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func refresh() async throws {
        recorded.append(.refresh)
        resumeWaiters()
    }

    func reloadVisibleWindow() async throws {
        recorded.append(.reload)
        resumeWaiters()
    }

    func waitForMessages(count: Int) async {
        guard recorded.count < count else { return }

        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func recordedMessages() -> [Message] {
        recorded
    }

    private func resumeWaiters() {
        guard !continuations.isEmpty else { return }

        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume() }
    }
}
