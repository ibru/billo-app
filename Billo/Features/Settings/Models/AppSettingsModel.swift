//  Created by Jiri Urbasek on 12/09/25.

import SwiftData
import Foundation
import Observation

enum CurrencyError: LocalizedError, Equatable {
    case invalidCode(String)
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCode(let code):
            return String(localized: "Invalid currency code: \(code)")
        case .saveFailed(let reason):
            return String(localized: "Failed to save currency change: \(reason)")
        }
    }
}

@MainActor
@Observable
final class AppSettingsModel {
    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let billsModel: BillsRefreshing
    @ObservationIgnored private let notificationCoordinator: NotificationCoordinating

    private(set) var currencyCode: String?
    private(set) var isUpdating: Bool = false

    private static let validCurrencyCodes: Set<String> = Set(Locale.commonISOCurrencyCodes)

    static var defaultCurrency: String? {
        Locale.current.currency?.identifier
    }

    init(
        modelContext: ModelContext,
        billsModel: BillsRefreshing,
        notificationCoordinator: NotificationCoordinating
    ) {
        self.modelContext = modelContext
        self.billsModel = billsModel
        self.notificationCoordinator = notificationCoordinator
    }

    func load() {
        let settings = AppSettings.current(in: modelContext)
        currencyCode = settings?.currencyCode
        Logger.log("Loaded currency code: \(currencyCode ?? "nil")", level: .debug)
    }

    func setCurrency(_ code: String) async throws {
        guard Self.isValidCurrencyCode(code) else {
            throw CurrencyError.invalidCode(code)
        }

        // Skip if same currency
        if currencyCode == code {
            Logger.log("Currency already set to \(code), skipping update", level: .debug)
            return
        }

        isUpdating = true
        defer { isUpdating = false }

        Logger.log("Setting global currency to \(code)", level: .info)

        do {
            // Update all bills
            let billDescriptor = FetchDescriptor<Bill>()
            let bills = try modelContext.fetch(billDescriptor)
            let now = Date()
            for bill in bills {
                bill.currencyCode = code
                bill.lastUpdatedDate = now
            }

            // Update all incomes
            let incomeDescriptor = FetchDescriptor<Income>()
            let incomes = try modelContext.fetch(incomeDescriptor)
            for income in incomes {
                income.currencyCode = code
                income.lastUpdatedDate = now
            }

            // Update or create singleton AppSettings
            let settings = AppSettings.getOrCreate(in: modelContext)
            settings.currencyCode = code
            settings.lastUpdatedDate = now

            // Atomic save
            try modelContext.save()

            currencyCode = code
            Logger.log("Currency updated to \(code), updated \(bills.count) bills and \(incomes.count) incomes", level: .info)

            // Post-save refresh - UI will update
            try? billsModel.refresh()

            // Refresh notifications with updated currency
            try? await notificationCoordinator.refreshAllNotifications(for: billsModel.bills)
            Logger.log("Notifications refreshed after currency change", level: .debug)
        } catch {
            Logger.log("Failed to set currency: \(error)", level: .error)
            throw CurrencyError.saveFailed(error.localizedDescription)
        }
    }

    static func isValidCurrencyCode(_ code: String) -> Bool {
        validCurrencyCodes.contains(code)
    }
}
