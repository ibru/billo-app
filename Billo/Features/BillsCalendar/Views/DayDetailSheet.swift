//  Created by Jiri Urbasek on 12/05/25.

import SwiftData
import SwiftUI

struct DayDetailSheet: View {
    let dayData: CalendarDayData
    let onMarkPaid: (BillOccurrence) async -> Void
    /// Called after a successful skip so the presenting calendar can rebuild
    /// its local state. `BillsModel.skipIncomeOccurrence` mutates the model's
    /// `incomeOccurrences` array contents (sets `isExcluded`) without
    /// changing element identities or count, so the calendar's existing
    /// `onChange(of: bills/incomes/payment count)` observers wouldn't notice.
    let onSkipIncome: () async -> Void

    @Query(sort: \CustomCategory.name) private var customCategories: [CustomCategory]
    @Environment(BillsModel.self) private var billsModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !dayData.incomeOccurrences.isEmpty {
                    Section("Income") {
                        ForEach(dayData.incomeOccurrences, id: \.id) { incomeOccurrence in
                            DaySheetIncomeRow(incomeOccurrence: incomeOccurrence)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if let occurrenceID = incomeOccurrence.occurrenceID {
                                        Button(role: .destructive) {
                                            skipOccurrence(occurrenceID)
                                        } label: {
                                            Label(
                                                String(
                                                    localized: "Skip",
                                                    comment: "Day detail: swipe action to skip a single past income occurrence"
                                                ),
                                                systemImage: "xmark.circle"
                                            )
                                        }
                                    }
                                }
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

    private func skipOccurrence(_ occurrenceID: PersistentIdentifier) {
        guard let occurrence = modelContext.model(for: occurrenceID) as? IncomeOccurrence else {
            Logger.log("Could not resolve IncomeOccurrence for skip", level: .warning)
            return
        }
        Task {
            do {
                try await billsModel.skipIncomeOccurrence(occurrence)
                await onSkipIncome()
                dismiss()
            } catch {
                // Don't dismiss on failure — the row would disappear and the user
                // would assume success. Leave the sheet open so they can retry.
                Logger.log("Failed to skip income occurrence: \(error)", level: .error)
            }
        }
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
    let incomeOccurrence: IncomeOccurrenceItem

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
