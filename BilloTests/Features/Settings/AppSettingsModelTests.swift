//  Created by Jiri Urbasek on 12/09/25.

import Testing
import SwiftData
import Foundation
@testable import Billo

@Suite("AppSettingsModel")
struct AppSettingsModelTests {

    @MainActor
    @Suite("setCurrency")
    struct SetCurrency {

        @Test func whenSettingCurrency_thenUpdatesBillsAndIncomesAndSettings() async throws {
            let (sut, testContext) = try makeSUT()
            let bill1 = testContext.insertBill(currencyCode: "USD")
            let bill2 = testContext.insertBill(currencyCode: "USD")
            let income = testContext.insertIncome(currencyCode: "EUR")

            try await sut.setCurrency("GBP")

            #expect(bill1.currencyCode == "GBP")
            #expect(bill2.currencyCode == "GBP")
            #expect(income.currencyCode == "GBP")
            #expect(sut.currencyCode == "GBP")
            #expect(testContext.currentSettingsCurrencyCode == "GBP")
        }

        @Test func whenSettingCurrency_thenUpdatesBillsLastUpdatedDate() async throws {
            let (sut, testContext) = try makeSUT()
            let originalDate = Date(timeIntervalSince1970: 1000)
            let bill = testContext.insertBill(currencyCode: "USD", lastUpdatedDate: originalDate)

            try await sut.setCurrency("EUR")

            #expect(bill.lastUpdatedDate > originalDate)
        }

        @Test func whenSettingCurrency_thenDoesNotTouchPayments() async throws {
            let (sut, testContext) = try makeSUT()
            let bill = testContext.insertBill(currencyCode: "USD")
            let payment = testContext.insertPayment(for: bill, amount: 100)
            let originalPaymentDate = payment.createdDate
            let originalPaymentAmount = payment.amount

            try await sut.setCurrency("EUR")

            #expect(payment.createdDate == originalPaymentDate)
            #expect(payment.amount == originalPaymentAmount)
        }

        @Test func whenSettingSameCurrency_thenIsNoOp() async throws {
            let (sut, testContext) = try makeSUT()
            testContext.insertSettings(currencyCode: "USD")
            sut.load()

            try await sut.setCurrency("USD")

            #expect(testContext.settingsCount == 1)
        }

        @Test func whenSettingInvalidCurrency_thenThrowsError() async throws {
            let (sut, _) = try makeSUT()

            await #expect {
                try await sut.setCurrency("INVALID")
            } throws: { error in
                guard case CurrencyError.invalidCode(let code) = error else { return false }
                return code == "INVALID"
            }
        }

        @Test func whenSettingValidCurrencies_thenSucceeds() async throws {
            let (sut, _) = try makeSUT()

            try await sut.setCurrency("USD")
            #expect(sut.currencyCode == "USD")

            try await sut.setCurrency("EUR")
            #expect(sut.currencyCode == "EUR")

            try await sut.setCurrency("JPY")
            #expect(sut.currencyCode == "JPY")
        }

        @Test func whenSettingCurrencyWithEmptyDatabase_thenSucceeds() async throws {
            let (sut, testContext) = try makeSUT()

            try await sut.setCurrency("EUR")

            #expect(sut.currencyCode == "EUR")
            #expect(testContext.currentSettingsCurrencyCode == "EUR")
        }

        @Test func whenSettingCurrency_thenTriggersRefresh() async throws {
            let (sut, testContext) = try makeSUT()
            testContext.insertBill(currencyCode: "USD")

            try await sut.setCurrency("EUR")

            #expect(testContext.billsModelSpy.refreshCallCount == 1)
        }

        @Test func whenSettingCurrency_thenRefreshesNotifications() async throws {
            let (sut, testContext) = try makeSUT()
            let bill = testContext.insertBill(currencyCode: "USD")
            testContext.billsModelSpy.bills = [bill]

            try await sut.setCurrency("EUR")

            #expect(testContext.notificationCoordinatorSpy.refreshAllNotificationsCalls.count == 1)
            #expect(testContext.notificationCoordinatorSpy.refreshAllNotificationsCalls.first == [bill])
        }

        @Test func whenSettingCurrencyMultipleTimes_thenUsesSingletonStorage() async throws {
            let (sut, testContext) = try makeSUT()

            try await sut.setCurrency("USD")
            try await sut.setCurrency("EUR")
            try await sut.setCurrency("GBP")

            #expect(testContext.settingsCount == 1)
            #expect(testContext.currentSettingsCurrencyCode == "GBP")
        }

    }

    @MainActor
    @Suite("CurrencyError")
    struct CurrencyErrorTests {

        @Test func whenInvalidCode_thenErrorDescriptionContainsCode() {
            let error = CurrencyError.invalidCode("XYZ")

            #expect(error.localizedDescription.contains("XYZ"))
        }

        @Test func whenSaveFailed_thenErrorDescriptionContainsReason() {
            let error = CurrencyError.saveFailed("Database connection lost")

            #expect(error.localizedDescription.contains("Database connection lost"))
        }

        @Test func whenComparingErrors_thenEquatableWorks() {
            let error1 = CurrencyError.invalidCode("USD")
            let error2 = CurrencyError.invalidCode("USD")
            let error3 = CurrencyError.invalidCode("EUR")

            #expect(error1 == error2)
            #expect(error1 != error3)
        }

        @Test func whenComparingSaveFailedErrors_thenEquatableWorks() {
            let error1 = CurrencyError.saveFailed("reason")
            let error2 = CurrencyError.saveFailed("reason")
            let error3 = CurrencyError.saveFailed("different")

            #expect(error1 == error2)
            #expect(error1 != error3)
        }
    }

    @MainActor
    @Suite("load")
    struct Load {

        @Test func whenLoading_thenFetchesExistingSettings() async throws {
            let (sut, testContext) = try makeSUT()
            testContext.insertSettings(currencyCode: "EUR")

            sut.load()

            #expect(sut.currencyCode == "EUR")
        }

        @Test func whenLoadingWithNoSettings_thenCurrencyIsNil() async throws {
            let (sut, _) = try makeSUT()

            sut.load()

            #expect(sut.currencyCode == nil)
        }
    }

    @MainActor
    @Suite("isValidCurrencyCode")
    struct IsValidCurrencyCode {

        @Test func whenCheckingValidCodes_thenReturnsTrue() {
            #expect(AppSettingsModel.isValidCurrencyCode("USD") == true)
            #expect(AppSettingsModel.isValidCurrencyCode("EUR") == true)
            #expect(AppSettingsModel.isValidCurrencyCode("GBP") == true)
            #expect(AppSettingsModel.isValidCurrencyCode("JPY") == true)
            #expect(AppSettingsModel.isValidCurrencyCode("CZK") == true)
        }

        @Test func whenCheckingInvalidCodes_thenReturnsFalse() {
            #expect(AppSettingsModel.isValidCurrencyCode("INVALID") == false)
            #expect(AppSettingsModel.isValidCurrencyCode("XXX") == false)
            #expect(AppSettingsModel.isValidCurrencyCode("") == false)
            #expect(AppSettingsModel.isValidCurrencyCode("US") == false)
        }
    }

    @MainActor
    @Suite("defaultCurrency")
    struct DefaultCurrency {

        @Test func whenLocaleHasCurrency_thenDefaultCurrencyReturnsIt() {
            let defaultCurrency = AppSettingsModel.defaultCurrency

            // Verifies implementation uses locale - value varies by test environment
            if let localeCurrency = Locale.current.currency?.identifier {
                #expect(defaultCurrency == localeCurrency)
            }
        }
    }
}

// MARK: - makeSUT & Factories

@MainActor
private func makeSUT() throws -> (sut: AppSettingsModel, testContext: TestContext) {
    let testContext = try TestContext()

    let sut = AppSettingsModel(
        modelContext: testContext.modelContext,
        billsModel: testContext.billsModelSpy,
        notificationCoordinator: testContext.notificationCoordinatorSpy
    )

    return (sut, testContext)
}

/// Encapsulates test infrastructure and provides domain-focused helpers
@MainActor
private final class TestContext {
    let modelContext: ModelContext
    let billsModelSpy: BillsModelSpy
    let notificationCoordinatorSpy: NotificationCoordinatorSpy

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Bill.self, Payment.self, RecurrenceRule.self, Income.self, CustomCategory.self, AppSettings.self,
            configurations: config
        )
        self.modelContext = ModelContext(container)
        self.billsModelSpy = BillsModelSpy()
        self.notificationCoordinatorSpy = NotificationCoordinatorSpy()
    }

    // MARK: - Insert Helpers

    @discardableResult
    func insertBill(
        name: String = UUID().uuidString,
        amount: Decimal = Decimal(Int.random(in: 10...1000)),
        currencyCode: String = "USD",
        dueDate: Date = Date(),
        lastUpdatedDate: Date? = nil
    ) -> Bill {
        let bill = Bill(
            name: name,
            amount: amount,
            currencyCode: currencyCode,
            dueDate: dueDate
        )
        if let lastUpdatedDate {
            bill.lastUpdatedDate = lastUpdatedDate
        }
        modelContext.insert(bill)
        try? modelContext.save()
        return bill
    }

    @discardableResult
    func insertIncome(
        name: String = UUID().uuidString,
        amount: Decimal = Decimal(Int.random(in: 100...5000)),
        currencyCode: String = "USD",
        frequency: RepeatIntervalType = .monthly,
        nextDate: Date = Date()
    ) -> Income {
        let income = Income(
            name: name,
            amount: amount,
            currencyCode: currencyCode,
            frequency: frequency,
            nextDate: nextDate
        )
        modelContext.insert(income)
        try? modelContext.save()
        return income
    }

    @discardableResult
    func insertPayment(
        for bill: Bill,
        amount: Decimal = Decimal(Int.random(in: 10...500)),
        datePaid: Date = Date()
    ) -> Payment {
        let payment = Payment(
            amount: amount,
            datePaid: datePaid,
            occurrenceDate: bill.dueDate,
            confirmationNumber: nil,
            notes: nil,
            bill: bill
        )
        modelContext.insert(payment)
        try? modelContext.save()
        return payment
    }

    @discardableResult
    func insertSettings(currencyCode: String) -> AppSettings {
        let settings = AppSettings(currencyCode: currencyCode)
        modelContext.insert(settings)
        try? modelContext.save()
        return settings
    }

    // MARK: - Query Helpers

    var currentSettingsCurrencyCode: String? {
        AppSettings.current(in: modelContext)?.currencyCode
    }

    var settingsCount: Int {
        (try? modelContext.fetchCount(FetchDescriptor<AppSettings>())) ?? 0
    }
}

// MARK: - Test Doubles

private final class BillsModelSpy: BillsRefreshing {
    var refreshCallCount = 0
    var bills: [Bill] = []

    func refresh() throws {
        refreshCallCount += 1
    }
}
