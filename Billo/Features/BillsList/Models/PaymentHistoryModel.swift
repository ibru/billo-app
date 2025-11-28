//  Created by Jiri Urbasek on 11/27/25.

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class PaymentHistoryModel: PaymentHistoryRefreshing {
    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let batchSize: Int

    private(set) var isHistoryVisible = false
    private(set) var displayedPayments: [Payment] = []
    private(set) var hasMorePayments = true
    private(set) var isLoading = false

    init(modelContext: ModelContext, batchSize: Int = 20) {
        self.modelContext = modelContext
        self.batchSize = batchSize
    }

    // MARK: - Visibility

    func toggleHistory() async throws {
        isHistoryVisible.toggle()

        guard isHistoryVisible else { return }

        if displayedPayments.isEmpty {
            try await loadInitialPayments()
        } else {
            try await reloadVisibleWindow()
        }
    }

    // MARK: - Paging

    func loadInitialPayments() async throws {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        let newestPayments = try fetchPayments(before: nil)

        displayedPayments = Array(newestPayments.reversed())
        hasMorePayments = newestPayments.count == batchSize

        if displayedPayments.isEmpty {
            hasMorePayments = false
        }
    }

    func loadNextBatch() async throws {
        guard !isLoading else { return }

        if displayedPayments.isEmpty {
            try await loadInitialPayments()
            return
        }

        guard hasMorePayments else { return }

        guard let oldestDate = displayedPayments.first?.datePaid else {
            hasMorePayments = false
            return
        }

        isLoading = true
        defer { isLoading = false }

        let olderPayments = try fetchPayments(before: oldestDate)

        if olderPayments.isEmpty {
            hasMorePayments = false
            return
        }

        displayedPayments.insert(contentsOf: Array(olderPayments.reversed()), at: 0)
        hasMorePayments = olderPayments.count == batchSize
    }

    // MARK: - PaymentHistoryRefreshing

    func refresh() async throws {
        guard isHistoryVisible else { return }

        guard let newestDate = displayedPayments.last?.datePaid else {
            try await loadInitialPayments()
            return
        }

        let descriptor = FetchDescriptor<Payment>(
            predicate: #Predicate { payment in
                payment.datePaid > newestDate
            },
            sortBy: [SortDescriptor(\.datePaid, order: .forward)]
        )

        let newerPayments = try modelContext.fetch(descriptor)

        guard !newerPayments.isEmpty else { return }

        displayedPayments.append(contentsOf: newerPayments)
    }

    func reloadVisibleWindow() async throws {
        guard isHistoryVisible, !displayedPayments.isEmpty else { return }

        let oldestDate = displayedPayments.first?.datePaid ?? .distantPast
        let newestDate = displayedPayments.last?.datePaid ?? .distantFuture

        let descriptor = FetchDescriptor<Payment>(
            predicate: #Predicate { payment in
                payment.datePaid >= oldestDate && payment.datePaid <= newestDate
            },
            sortBy: [SortDescriptor(\.datePaid, order: .forward)]
        )

        let refreshed = try modelContext.fetch(descriptor)
        displayedPayments = refreshed
    }

    // MARK: - Helpers

    private func fetchPayments(before threshold: Date?) throws -> [Payment] {
        let predicate: Predicate<Payment>? = threshold.map { date in
            #Predicate { payment in
                payment.datePaid < date
            }
        }

        var descriptor = FetchDescriptor<Payment>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.datePaid, order: .reverse)]
        )

        descriptor.fetchLimit = batchSize

        return try modelContext.fetch(descriptor)
    }
}
