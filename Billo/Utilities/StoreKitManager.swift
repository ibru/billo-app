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
        static let monthly: String = "com.jiriurbasek.Billo.pro.sub.monthly"
        static let yearly: String = "com.jiriurbasek.Billo.pro.sub.yearly"
        static let lifetime: String = "com.jiriurbasek.Billo.pro.lifetime"
        static let all: [String] = [monthly, yearly, lifetime]
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

        /// Stable, locale-independent key for analytics — never the
        /// localized message (unaggregatable and an uncontrolled string).
        var analyticsReason: String {
            switch self {
            case .cancelled: "cancelled"
            case .pending: "pending"
            case .unverified: "unverified"
            case .unknown: "unknown"
            case .failed: "purchase_failed"
            }
        }
    }

    var isPro: Bool = false
    var products: [Product] = []
    var productsState: LoadState = .idle

    private let cache: ProEntitlementCaching
    private var transactionUpdatesTask: Task<Void, Never>?
    private var productsLoadTask: Task<[Product], Error>?
    private var didStart: Bool = false

    /// Seeds `isPro` synchronously from the last-known cached entitlement so a
    /// paying user relaunching offline (or during a slow StoreKit response)
    /// never sees locked features — `refreshEntitlements()` remains the source
    /// of truth and overwrites the cache once it lands.
    init(cache: ProEntitlementCaching = UserDefaultsProEntitlementCache()) {
        self.cache = cache
        self.isPro = cache.isPro
    }

    /// Previews, tests, and QA schemes ONLY: a fixed entitlement without
    /// touching StoreKit or UserDefaults. Never use in the production launch
    /// path — it bypasses the entitlement cache and real StoreKit entirely.
    convenience init(isPro: Bool) {
        self.init(cache: NoopProEntitlementCache())
        self.isPro = isPro
    }

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

        applyEntitlement(isActive: foundActive)
    }

    /// Single write path for the entitlement: updates `isPro` and persists the
    /// optimistic cache together. Internal (not private) so tests can drive
    /// entitlement changes deterministically — iterating the real
    /// `Transaction.currentEntitlements` is not controllable in the test host.
    func applyEntitlement(isActive: Bool) {
        isPro = isActive
        cache.save(isPro: isActive)
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Purchase

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

// MARK: - Pro entitlement cache

/// Lightweight optimistic cache for the Pro entitlement. Backed by
/// `UserDefaults` in production; a spy in tests; a no-op for previews and the
/// QA schemes (so a cached `true` can never leak into a gating QA session).
/// The cache only seeds the launch value — `Transaction.currentEntitlements`
/// overwrites it on every refresh.
protocol ProEntitlementCaching {
    var isPro: Bool { get }
    func save(isPro: Bool)
}

final class UserDefaultsProEntitlementCache: ProEntitlementCaching {
    private static let key = "billo.proEntitlement.isPro"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isPro: Bool {
        defaults.bool(forKey: Self.key)
    }

    func save(isPro: Bool) {
        defaults.set(isPro, forKey: Self.key)
    }
}

final class NoopProEntitlementCache: ProEntitlementCaching {
    var isPro: Bool { false }
    func save(isPro: Bool) {}
}
