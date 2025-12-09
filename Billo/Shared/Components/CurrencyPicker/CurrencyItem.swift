//  Created by Jiri Urbasek on 12/09/25.

import Foundation

struct CurrencyItem: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }

    /// Returns the currency symbol (e.g., "$" for USD, "€" for EUR)
    var symbol: String {
        Self.symbol(for: code)
    }

    static func allCurrencies() -> [CurrencyItem] {
        Locale.commonISOCurrencyCodes.map { code in
            CurrencyItem(code: code, name: localizedName(for: code))
        }.sorted { $0.name < $1.name }
    }

    static func filtered(by searchText: String) -> [CurrencyItem] {
        let currencies = allCurrencies()
        if searchText.isEmpty {
            return currencies
        }
        let query = searchText.lowercased()
        return currencies.filter {
            $0.code.lowercased().contains(query) || $0.name.lowercased().contains(query)
        }
    }

    static func filteredPopularCurrencies(by searchText: String) -> [CurrencyItem] {
        let currencies = popularCurrencies
        if searchText.isEmpty {
            return currencies
        }
        let query = searchText.lowercased()
        return currencies.filter {
            $0.code.lowercased().contains(query) || $0.name.lowercased().contains(query)
        }
    }

    static func localizedName(for code: String) -> String {
        Locale.current.localizedString(forCurrencyCode: code) ?? code
    }

    static func symbol(for code: String) -> String {
        let locale = Locale(identifier: Locale.identifier(fromComponents: [NSLocale.Key.currencyCode.rawValue: code]))
        return locale.currencySymbol ?? code
    }

    /// Most commonly used currencies, displayed at the top of the picker
    static var popularCurrencies: [CurrencyItem] {
        let popularCodes = ["USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "CNY", "CZK", "PLN"]
        return popularCodes.compactMap { code in
            CurrencyItem(code: code, name: localizedName(for: code))
        }
    }

    /// Returns the device's default currency based on locale, if available
    static var deviceCurrency: CurrencyItem? {
        guard let currencyCode = Locale.current.currency?.identifier else { return nil }
        return CurrencyItem(code: currencyCode, name: localizedName(for: currencyCode))
    }
}
