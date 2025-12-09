//  Created by Jiri Urbasek on 12/09/25.

import Testing
import Foundation
@testable import Billo

@MainActor
@Suite("CurrencyItem")
struct CurrencyItemTests {

    @MainActor
    @Suite("allCurrencies")
    struct AllCurrencies {

        @Test func whenCalled_thenReturnsAllISOCurrencies() {
            let currencies = CurrencyItem.allCurrencies()

            #expect(currencies.count == Locale.commonISOCurrencyCodes.count)
        }

        @Test func whenCalled_thenResultIsSortedByName() {
            let currencies = CurrencyItem.allCurrencies()
            let names = currencies.map(\.name)

            #expect(names == names.sorted())
        }

        @Test func whenCalled_thenEachItemHasCodeAndName() {
            let currencies = CurrencyItem.allCurrencies()

            for currency in currencies {
                #expect(!currency.code.isEmpty)
                #expect(!currency.name.isEmpty)
            }
        }

        @Test func whenCalled_thenContainsCommonCurrencies() {
            let currencies = CurrencyItem.allCurrencies()
            let codes = Set(currencies.map(\.code))

            #expect(codes.contains("USD"))
            #expect(codes.contains("EUR"))
            #expect(codes.contains("GBP"))
            #expect(codes.contains("JPY"))
            #expect(codes.contains("CZK"))
        }
    }

    @MainActor
    @Suite("filtered")
    struct Filtered {

        @Test func whenSearchTextIsEmpty_thenReturnsAllCurrencies() {
            let filtered = CurrencyItem.filtered(by: "")

            #expect(filtered.count == CurrencyItem.allCurrencies().count)
        }

        @Test func whenSearchingByCode_thenReturnsCurrenciesMatchingCode() {
            let filtered = CurrencyItem.filtered(by: "USD")

            #expect(filtered.contains { $0.code == "USD" })
        }

        @Test func whenSearchingByCodeLowercase_thenReturnsCurrenciesMatchingCode() {
            let filtered = CurrencyItem.filtered(by: "usd")

            #expect(filtered.contains { $0.code == "USD" })
        }

        @Test func whenSearchingByPartialCode_thenReturnsCurrenciesContainingQuery() {
            let filtered = CurrencyItem.filtered(by: "US")

            #expect(filtered.contains { $0.code == "USD" })
            // Should also match AUD, etc. that contain "US" in name or code
        }

        @Test func whenSearchingByName_thenReturnsCurrenciesMatchingName() {
            let filtered = CurrencyItem.filtered(by: "Dollar")

            // Should match currencies with "Dollar" in their localized name
            #expect(filtered.allSatisfy { currency in
                currency.name.lowercased().contains("dollar") ||
                currency.code.lowercased().contains("dollar")
            })
        }

        @Test func whenSearchingByNonExistentTerm_thenReturnsEmptyArray() {
            let filtered = CurrencyItem.filtered(by: "XYZNONEXISTENT123")

            #expect(filtered.isEmpty)
        }

        @Test func whenSearchingIsCaseInsensitive_thenMatchesRegardlessOfCase() {
            let filteredLower = CurrencyItem.filtered(by: "eur")
            let filteredUpper = CurrencyItem.filtered(by: "EUR")
            let filteredMixed = CurrencyItem.filtered(by: "Eur")

            #expect(filteredLower.map(\.code) == filteredUpper.map(\.code))
            #expect(filteredUpper.map(\.code) == filteredMixed.map(\.code))
        }
    }

    @MainActor
    @Suite("localizedName")
    struct LocalizedName {

        @Test func whenCalledWithValidCode_thenReturnsLocalizedName() {
            let name = CurrencyItem.localizedName(for: "USD")

            // The exact name depends on locale, but it should not be empty
            #expect(!name.isEmpty)
            // Should not just return the code back (unless locale has no translation)
            // For USD, all locales should have a name
            #expect(name != "USD" || Locale.current.localizedString(forCurrencyCode: "USD") == "USD")
        }

        @Test func whenCalledWithInvalidCode_thenReturnsCodeItself() {
            let invalidCode = "INVALIDCODE123"
            let name = CurrencyItem.localizedName(for: invalidCode)

            #expect(name == invalidCode)
        }

        @Test func whenCalledWithCommonCodes_thenReturnsNonEmptyNames() {
            let codes = ["USD", "EUR", "GBP", "JPY", "CZK"]

            for code in codes {
                let name = CurrencyItem.localizedName(for: code)
                #expect(!name.isEmpty, "Expected non-empty name for \(code)")
            }
        }
    }

    @MainActor
    @Suite("identity")
    struct Identity {

        @Test func whenCreated_thenIdEqualsCode() {
            let currency = CurrencyItem(code: "USD", name: "US Dollar")

            #expect(currency.id == "USD")
        }

        @Test func whenTwoCurrenciesHaveSameCode_thenTheyAreEqual() {
            let currency1 = CurrencyItem(code: "EUR", name: "Euro")
            let currency2 = CurrencyItem(code: "EUR", name: "Euro")

            #expect(currency1 == currency2)
        }

        @Test func whenTwoCurrenciesHaveDifferentCodes_thenTheyAreNotEqual() {
            let currency1 = CurrencyItem(code: "USD", name: "US Dollar")
            let currency2 = CurrencyItem(code: "EUR", name: "Euro")

            #expect(currency1 != currency2)
        }
    }
}
