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
                    Label("Amount", systemImage: "wallet.bifold")
                    Spacer()
                    Text(income.amount, format: .currency(code: income.currencyCode))
                        .foregroundStyle(DesignSystem.Color.greenIncome)
                        .fontWeight(.semibold)
                }

                HStack {
                    Label("Start Date", systemImage: "calendar")
                    Spacer()
                    Text(income.startDate, style: .date)
                        .foregroundStyle(.secondary)
                }

                if let rule = income.recurrenceRule, rule.endConditionType == .endDate, let endDate = rule.endDate {
                    HStack {
                        Label("End Date", systemImage: "calendar.badge.clock")
                        Spacer()
                        Text(endDate, style: .date)
                            .foregroundStyle(.secondary)
                    }
                }

                if let rule = income.recurrenceRule {
                    HStack {
                        Label("Repeats", systemImage: "repeat")
                        Spacer()
                        Text(rule.pattern.displayName)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        Label("Repeats", systemImage: "repeat")
                        Spacer()
                        Text(RecurrencePreset.none.displayName)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete Income", systemImage: "trash")
                }
            }
        }
        .navigationTitle(income.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            IncomeEditView(mode: .editing(income))
        }
        .alert("Delete Income?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    try? await billsModel.deleteIncome(income)
                    dismiss()
                }
            }
        } message: {
            Text("This will permanently delete \"\(income.name)\".")
        }
    }
}
