//  Created by Jiri Urbasek on 12/09/25.

import SwiftUI

struct SettingsCurrencyPickerView: View {
    @Environment(AppSettingsModel.self) private var appSettingsModel
    @Environment(AnalyticsModel.self) private var analytics
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var pendingCurrencyCode: String?
    @State private var showConfirmation = false
    @State private var isUpdating = false
    @State private var errorMessage: String?

    private var currentCurrencyCode: String {
        appSettingsModel.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    private var filteredPopularCurrencies: [CurrencyItem] {
        CurrencyItem.filteredPopularCurrencies(by: searchText)
    }

    private var filteredCurrencies: [CurrencyItem] {
        CurrencyItem.filtered(by: searchText)
    }

	    var body: some View {
	        List {
	            if !filteredPopularCurrencies.isEmpty {
	                Section("Popular Currencies") {
	                    ForEach(filteredPopularCurrencies) { currency in
	                        CurrencyRow(
	                            currency: currency,
	                            isSelected: currentCurrencyCode == currency.code
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleCurrencyTap(currency.code)
                        }
                    }
                }
            }
	
	            if !filteredCurrencies.isEmpty {
	                Section("All Currencies") {
	                    ForEach(filteredCurrencies) { currency in
	                        CurrencyRow(
	                            currency: currency,
	                            isSelected: currentCurrencyCode == currency.code
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleCurrencyTap(currency.code)
                        }
                    }
	                }
	            }
	        }
	        .navigationTitle("Currency")
	        .analyticsScreen(.currencyPicker)
	        .searchable(text: $searchText, prompt: Text("Search currencies"))
	        .disabled(isUpdating)
	        .overlay {
	            if isUpdating {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
	        }
	        .alert(
	            "Change Currency?",
	            isPresented: $showConfirmation,
	            presenting: pendingCurrencyCode
	        ) { _ in
	            Button("Cancel", role: .cancel) {
	                pendingCurrencyCode = nil
	            }
	            Button("Change") {
	                confirmCurrencyChange()
	            }
	        } message: { code in
	            let currencyName = CurrencyItem.localizedName(for: code)
            Text("Changing currency will relabel all existing bills and incomes to \(currencyName). Amounts will not be converted. This cannot be undone.")
	        }
	        .alert("Error", isPresented: .constant(errorMessage != nil)) {
	            Button("OK") { errorMessage = nil }
	        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
    }

    private func handleCurrencyTap(_ code: String) {
        guard code != currentCurrencyCode else { return }
        pendingCurrencyCode = code
        showConfirmation = true
    }

    private func confirmCurrencyChange() {
        guard let code = pendingCurrencyCode else { return }
        Task {
            isUpdating = true
            defer {
                isUpdating = false
                pendingCurrencyCode = nil
            }
            do {
                try await appSettingsModel.setCurrency(code)
                analytics.capture(.currencyChanged(currencyCode: code, source: "settings"))
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

}

#Preview {
    let preview = BilloPreviewContainer.withSampleData()
    return NavigationStack {
        SettingsCurrencyPickerView()
    }
    .environment(preview.appSettingsModel)
    .environment(AnalyticsModel())
}
