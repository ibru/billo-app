//  Created by Jiri Urbasek on 12/10/25.

import SwiftUI

struct IncomeListView: View {
    @Environment(BillsModel.self) private var billsModel

    @State private var showingAddIncome = false

    var body: some View {
        List {
            if billsModel.incomes.isEmpty {
                EmptyStateView()
            } else {
                ForEach(billsModel.incomes) { income in
                    NavigationLink(value: income) {
                        IncomeRowView(income: income)
                    }
                }
                .onDelete(perform: deleteIncome)
            }
        }
        .navigationTitle(String(localized: "Income"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddIncome = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddIncome) {
            IncomeEditView(mode: .adding)
        }
    }

    private func deleteIncome(at offsets: IndexSet) {
        // Capture incomes to delete before launching async task to avoid index shifts
        let incomesToDelete = offsets.map { billsModel.incomes[$0] }
        Task {
            for income in incomesToDelete {
                try? await billsModel.deleteIncome(income)
            }
        }
    }
}

private struct EmptyStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label(String(localized: "No Income"), systemImage: "banknote")
        } description: {
            Text(String(localized: "Add your income sources to track your budget"))
        }
    }
}

struct IncomeRowView: View {
    let income: Income

    private var formattedAmount: String {
        income.amount.formatted(.currency(code: income.currencyCode))
    }

    private var frequencyLabel: String {
        income.recurrenceRule?.pattern.displayName ?? String(localized: "One-time")
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "banknote")
                .foregroundStyle(DesignSystem.Color.income)
                .font(.title2)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text(income.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let rule = income.recurrenceRule {
                    Text(rule.pattern.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(String(localized: "One-time"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.extraSmall) {
                Text(income.amount, format: .currency(code: income.currencyCode))
                    .font(.headline)
                    .foregroundStyle(DesignSystem.Color.income)

                Text(income.startDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.small)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Income: \(income.name), \(formattedAmount), \(frequencyLabel)")
    }
}
