//  Created by Jiri Urbasek on 12/28/25.

import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class StoreKitManager {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum ProductID {
        static let weekly: String = "com.jiriurbasek.Billo.pro.sub.weekly"
        static let yearly: String = "com.jiriurbasek.Billo.pro.sub.yearly"
        static let all: [String] = [weekly, yearly]
    }

    enum PurchaseError: LocalizedError, Equatable {
        case cancelled
        case pending
        case unverified
        case unknown
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .cancelled:
                return String(localized: "Purchase cancelled.")
            case .pending:
                return String(localized: "Purchase pending approval.")
            case .unverified:
                return String(localized: "Purchase could not be verified.")
            case .unknown:
                return String(localized: "Unknown purchase state.")
            case .failed(let message):
                return message
            }
        }
    }

    var isPro: Bool = false
    var products: [Product] = []
    var productsState: LoadState = .idle

    private var transactionUpdatesTask: Task<Void, Never>?
    private var productsLoadTask: Task<[Product], Error>?
    private var didStart: Bool = false

    init() {}

    func start() {
        guard didStart == false else { return }
        didStart = true

        transactionUpdatesTask?.cancel()
        transactionUpdatesTask = Task { [weak self] in
            for await _ in Transaction.updates {
                guard let self else { return }
                await self.refreshEntitlements()
            }
        }

        Task {
            await refreshEntitlements()
            await loadProductsIfNeeded()
        }
    }

    func loadProducts() async {
        productsState = .loading
        do {
            let fetched = try await Product.products(for: ProductID.all)
            let order = ProductID.all
            products = fetched.sorted { lhs, rhs in
                let li = order.firstIndex(of: lhs.id) ?? Int.max
                let ri = order.firstIndex(of: rhs.id) ?? Int.max
                return li < ri
            }
            productsState = .loaded
        } catch {
            productsState = .failed(error.localizedDescription)
        }
    }

    func loadProductsIfNeeded() async {
        switch productsState {
        case .loaded:
            return
        case .loading:
            if let productsLoadTask {
                _ = try? await productsLoadTask.value
            }
            return
        case .idle, .failed:
            break
        }

        productsState = .loading
        let task = Task { try await Product.products(for: ProductID.all) }
        productsLoadTask = task

        do {
            let fetched = try await task.value
            let order = ProductID.all
            products = fetched.sorted { lhs, rhs in
                let li = order.firstIndex(of: lhs.id) ?? Int.max
                let ri = order.firstIndex(of: rhs.id) ?? Int.max
                return li < ri
            }
            productsState = .loaded
        } catch {
            productsState = .failed(error.localizedDescription)
        }

        productsLoadTask = nil
    }

    func refreshEntitlements() async {
        var foundActive = false
        let now = Date()

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard ProductID.all.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard transaction.expirationDate.map({ $0 > now }) ?? true else { continue }
            foundActive = true
            break
        }

        isPro = foundActive
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    func purchase(_ product: Product) async -> Result<Void, PurchaseError> {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return .failure(.unverified)
                }
                await transaction.finish()
                await refreshEntitlements()
                return .success(())
            case .userCancelled:
                return .failure(.cancelled)
            case .pending:
                return .failure(.pending)
            @unknown default:
                return .failure(.unknown)
            }
        } catch {
            return .failure(.failed(error.localizedDescription))
        }
    }
}
