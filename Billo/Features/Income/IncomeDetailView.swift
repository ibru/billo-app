//  Created by Jiri Urbasek on 12/10/25.

import SwiftUI

struct IncomeDetailView: View {
    let income: Income

    @Environment(BillsModel.self) private var billsModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    var body: some View {
        List {
            Section {
                HStack {
                    Label(String(localized: "Amount"), systemImage: "banknote")
                    Spacer()
                    Text(income.amount, format: .currency(code: income.currencyCode))
                        .foregroundStyle(DesignSystem.Color.income)
                        .fontWeight(.semibold)
                }

                HStack {
                    Label(String(localized: "Start Date"), systemImage: "calendar")
                    Spacer()
                    Text(income.startDate, style: .date)
                        .foregroundStyle(.secondary)
                }

                if let endDate = income.endDate {
                    HStack {
                        Label(String(localized: "End Date"), systemImage: "calendar.badge.clock")
                        Spacer()
                        Text(endDate, style: .date)
                            .foregroundStyle(.secondary)
                    }
                }

                if let rule = income.recurrenceRule {
                    HStack {
                        Label(String(localized: "Repeats"), systemImage: "repeat")
                        Spacer()
                        Text(rule.pattern.displayName)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        Label(String(localized: "Repeats"), systemImage: "repeat")
                        Spacer()
                        Text(String(localized: "One-time"))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label(String(localized: "Delete Income"), systemImage: "trash")
                }
            }
        }
        .navigationTitle(income.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "Edit")) {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            IncomeEditView(mode: .editing(income))
        }
        .alert(String(localized: "Delete Income?"), isPresented: $showingDeleteAlert) {
            Button(String(localized: "Cancel"), role: .cancel) { }
            Button(String(localized: "Delete"), role: .destructive) {
                Task {
                    try? await billsModel.deleteIncome(income)
                    dismiss()
                }
            }
        } message: {
            Text(String(localized: "This will permanently delete \"\(income.name)\"."))
        }
    }
}
