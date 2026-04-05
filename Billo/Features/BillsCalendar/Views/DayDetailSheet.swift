//  Created by Jiri Urbasek on 12/05/25.

import SwiftData
import SwiftUI

struct DayDetailSheet: View {
    let dayData: CalendarDayData
    let onMarkPaid: (BillOccurrence) async -> Void

    @Query(sort: \CustomCategory.name) private var customCategories: [CustomCategory]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !dayData.incomeOccurrences.isEmpty {
                    Section("Income") {
                        ForEach(dayData.incomeOccurrences, id: \.id) { incomeOccurrence in
                            DaySheetIncomeRow(incomeOccurrence: incomeOccurrence)
                        }
                    }
                }

                if !dayData.payments.isEmpty {
                    Section("Payments") {
                        ForEach(dayData.payments) { payment in
                            PaymentRowView(
                                payment: payment,
                                customCategories: customCategories,
                                leadingIconStyle: .checkmark,
                                accentColor: DesignSystem.Color.green
                            )
                        }
                    }
                }

                if !dayData.bills.isEmpty {
                    Section("Bills") {
                        ForEach(dayData.bills) { display in
                            BillRowView(
                                occurrence: display.occurrence,
                                customCategories: customCategories,
                                section: billSection(for: display)
                            )
                        }
                    }
                }
            }
            .navigationTitle(dayData.date.formatted(.dateTime.month(.wide).day()))
            .platformInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func billSection(for display: BillDisplay) -> BillSection {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDay = calendar.startOfDay(for: display.occurrence.dueDate)

        if dueDay < today { return .overdue }
        if dueDay == today { return .today }

        let sevenDays = calendar.date(byAdding: .day, value: 7, to: today) ?? today
        if dueDay <= sevenDays { return .next7Days }

        let thirtyDays = calendar.date(byAdding: .day, value: 30, to: today) ?? today
        if dueDay <= thirtyDays { return .next30Days }

        return .later
    }
}

private struct DaySheetIncomeRow: View {
    let incomeOccurrence: IncomeOccurrence

    private var formattedAmount: String {
        incomeOccurrence.amount.formatted(.currency(code: incomeOccurrence.currencyCode))
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "wallet.bifold")
                .font(.title3)
                .foregroundStyle(DesignSystem.Color.greenIncome)
                .frame(width: 36)

            Text(incomeOccurrence.name)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            HStack(spacing: 0) {
                Text("+")
                Text(incomeOccurrence.amount, format: .currency(code: incomeOccurrence.currencyCode))
            }
            .font(.subheadline)
            .foregroundStyle(DesignSystem.Color.greenIncome)
        }
        .padding(.vertical, DesignSystem.Spacing.small)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            localized: "Income: \(incomeOccurrence.name), \(formattedAmount)",
            comment: "Accessibility: day details income row label (name, amount)"
        ))
    }
}
