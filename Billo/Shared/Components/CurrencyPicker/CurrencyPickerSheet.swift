//  Created by Jiri Urbasek on 12/09/25.

import SwiftUI

/// A reusable currency picker presented as a sheet with popular currencies section
struct CurrencyPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCurrency: String
    @State private var searchText = ""

    private var filteredPopularCurrencies: [CurrencyItem] {
        CurrencyItem.filteredPopularCurrencies(by: searchText)
    }

    private var filteredCurrencies: [CurrencyItem] {
        CurrencyItem.filtered(by: searchText)
    }

    var body: some View {
        NavigationStack {
            List {
                if !filteredPopularCurrencies.isEmpty {
                    Section(String(localized: "Popular Currencies")) {
                        ForEach(filteredPopularCurrencies) { currency in
                            CurrencyRow(
                                currency: currency,
                                isSelected: currency.code == selectedCurrency
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedCurrency = currency.code
                                dismiss()
                            }
                        }
                    }
                }

                if !filteredCurrencies.isEmpty {
                    Section(String(localized: "All Currencies")) {
                        ForEach(filteredCurrencies) { currency in
                            CurrencyRow(
                                currency: currency,
                                isSelected: currency.code == selectedCurrency
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedCurrency = currency.code
                                dismiss()
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: Text("Search currencies"))
            .navigationTitle(String(localized: "Select Currency"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("CurrencyPickerSheet") {
    @Previewable @State var selectedCurrency = "USD"
    CurrencyPickerSheet(selectedCurrency: $selectedCurrency)
}
