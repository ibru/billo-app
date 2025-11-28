//  Created by Jiri Urbasek on 11/27/25.

import Foundation
import SwiftData
import Testing
@testable import Billo

@MainActor
@Suite("PaymentHistoryModel")
struct PaymentHistoryModelTests {
    @Test func whenToggleFirstTime_thenLoadsOldestFirstBatch() async throws {
        let (sut, _, payments) = try makeSUT(paymentCount: 30)

        try await sut.toggleHistory()

        #expect(sut.isHistoryVisible)
        #expect(sut.displayedPayments.count == 20)
        #expect(sut.hasMorePayments)

        let newestTwenty = payments
            .sorted { $0.datePaid > $1.datePaid }
            .prefix(20)
            .map(\.persistentModelID)

        let displayedIdentifiers = Set(sut.displayedPayments.map(\.persistentModelID))
        #expect(displayedIdentifiers == Set(newestTwenty))
        #expect(sut.displayedPayments.first?.datePaid ?? .distantPast < sut.displayedPayments.last?.datePaid ?? .distantFuture)
    }

    @Test func whenTogglingOff_thenKeepsCachedData() async throws {
        let (sut, _, _) = try makeSUT(paymentCount: 10)

        try await sut.toggleHistory()
        let cachedIDs = sut.displayedPayments.map(\.persistentModelID)

        try await sut.toggleHistory() // hide

        #expect(sut.isHistoryVisible == false)
        #expect(sut.displayedPayments.map(\.persistentModelID) == cachedIDs)
    }

    @Test func whenTogglingOnAfterHide_thenRestoresCachedPayments() async throws {
        let (sut, _, _) = try makeSUT(paymentCount: 8)

        try await sut.toggleHistory()
        let cachedIDs = sut.displayedPayments.map(\.persistentModelID)

        try await sut.toggleHistory() // hide
        #expect(!sut.isHistoryVisible)

        try await sut.toggleHistory() // show again

        #expect(sut.isHistoryVisible)
        #expect(sut.displayedPayments.map(\.persistentModelID) == cachedIDs)
    }

    @Test func whenLoadingNextBatch_thenPrependsOlderPayments() async throws {
        let (sut, _, _) = try makeSUT(paymentCount: 50, batchSize: 10)

        try await sut.loadInitialPayments()
        let originalFirst = sut.displayedPayments.first

        try await sut.loadNextBatch()

        #expect(sut.displayedPayments.count == 20)
        #expect(sut.displayedPayments.first?.datePaid ?? .distantPast < originalFirst?.datePaid ?? .distantFuture)
    }

    @Test func whenFewerThanBatchExists_thenMarksHasMoreFalse() async throws {
        let (sut, _, _) = try makeSUT(paymentCount: 5)

        try await sut.loadInitialPayments()

        #expect(sut.displayedPayments.count == 5)
        #expect(sut.hasMorePayments == false)
    }

    @Test func whenRefreshingWithNewerPayments_thenAppendsToEnd() async throws {
        let (sut, context, _) = try makeSUT(paymentCount: 5, batchSize: 5)
        try await sut.toggleHistory()
        let initialLatestDate = sut.displayedPayments.last?.datePaid ?? Date()

        let newPayment = Payment(
            amount: 200,
            datePaid: initialLatestDate.addingTimeInterval(3600),
            occurrenceDate: initialLatestDate,
            bill: nil
        )
        context.insert(newPayment)
        try context.save()

        try await sut.refresh()

        #expect(sut.displayedPayments.last?.persistentModelID == newPayment.persistentModelID)
        #expect(sut.displayedPayments.count == 6)
    }

    @Test func whenReloadingVisibleWindow_thenReflectsExternalDeletions() async throws {
        let (sut, context, _) = try makeSUT(paymentCount: 3, batchSize: 3)
        try await sut.toggleHistory()

        let originalCount = sut.displayedPayments.count
        let target = sut.displayedPayments[1]
        context.delete(target)
        try context.save()

        try await sut.reloadVisibleWindow()

        #expect(sut.displayedPayments.count == originalCount - 1)
        #expect(sut.displayedPayments.contains { $0.persistentModelID == target.persistentModelID } == false)
    }

    @Test func whenNoPaymentsExist_thenInitialLoadProducesEmptyState() async throws {
        let (sut, _, _) = try makeSUT(paymentCount: 0)

        try await sut.loadInitialPayments()

        #expect(sut.displayedPayments.isEmpty)
        #expect(sut.hasMorePayments == false)
    }

    @Test func whenReloadingWindow_thenPreservesHasMoreFlag() async throws {
        let (sut, context, _) = try makeSUT(paymentCount: 35, batchSize: 15)

        try await sut.toggleHistory()
        try await sut.loadNextBatch()
        let expectedHasMore = sut.hasMorePayments

        // mutate visible data to ensure reload work does something
        sut.displayedPayments.first?.notes = "updated"
        try context.save()

        try await sut.reloadVisibleWindow()

        #expect(sut.hasMorePayments == expectedHasMore)
        #expect(sut.displayedPayments.first?.notes == "updated")
    }
}

// MARK: - Helpers

@MainActor
private func makeSUT(paymentCount: Int, batchSize: Int = 20) throws -> (PaymentHistoryModel, ModelContext, [Payment]) {
    let schema = Schema([Bill.self, Payment.self])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let context = ModelContext(container)

    let payments = try makePayments(count: paymentCount, in: context)

    let sut = PaymentHistoryModel(modelContext: context, batchSize: batchSize)

    return (sut, context, payments)
}

@MainActor
@discardableResult
private func makePayments(count: Int, in context: ModelContext) throws -> [Payment] {
    let baseDate = Date()
    var payments: [Payment] = []

    for index in 0..<count {
        let paymentDate = baseDate.addingTimeInterval(TimeInterval(-index * 86_400))
        let payment = Payment(
            amount: Decimal((index + 1) * 10),
            datePaid: paymentDate,
            occurrenceDate: paymentDate,
            bill: nil
        )
        context.insert(payment)
        payments.append(payment)
    }

    try context.save()
    return payments
}
