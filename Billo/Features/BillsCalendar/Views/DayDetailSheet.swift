//  Created by Jiri Urbasek on 12/05/25.

import SwiftUI

struct DayDetailSheet: View {
    let dayData: CalendarDayData
    let calendar: Calendar
    let today: Date
    let onMarkPaid: (BillOccurrence) async -> Void

    @Environment(\.dismiss) private var dismiss

    private var unpaidOccurrences: [BillOccurrence] {
        dayData.occurrences.filter {
            $0.status(relativeTo: today, calendar: calendar) != .paid
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !dayData.incomeOccurrences.isEmpty {
                    Section(String(localized: "Income")) {
                        ForEach(dayData.incomeOccurrences, id: \.id) { incomeOccurrence in
                            IncomeOccurrenceRow(incomeOccurrence: incomeOccurrence)
                        }
                    }
                }

                if !unpaidOccurrences.isEmpty {
                    Section(String(localized: "Due")) {
                        ForEach(unpaidOccurrences) { occurrence in
                            DaySheetOccurrenceRow(
                                occurrence: occurrence,
                                onMarkPaid: {
                                    Task {
                                        await onMarkPaid(occurrence)
                                        dismiss()
                                    }
                                }
                            )
                        }
                    }
                }

                if !dayData.payments.isEmpty {
                    Section(String(localized: "Paid")) {
                        ForEach(dayData.payments) { payment in
                            PaymentRowView(
                                payment: payment,
                                customCategories: [],
                                leadingIconStyle: .checkmark,
                                accentColor: .green,
                                showsChevron: false
                            )
                        }
                    }
                }
            }
            .navigationTitle(dayData.date.formatted(.dateTime.month(.wide).day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct IncomeOccurrenceRow: View {
    let incomeOccurrence: IncomeOccurrence

    private var formattedAmount: String {
        incomeOccurrence.amount.formatted(.currency(code: incomeOccurrence.currencyCode))
    }

    var body: some View {
        HStack {
            Image(systemName: "banknote")
                .foregroundStyle(DesignSystem.Color.income)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(incomeOccurrence.name)
                    .font(.headline)
                Text(incomeOccurrence.amount, format: .currency(code: incomeOccurrence.currencyCode))
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Color.income)
            }

            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.small)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Income: \(incomeOccurrence.name), \(formattedAmount)")
    }
}

private struct DaySheetOccurrenceRow: View {
    let occurrence: BillOccurrence
    let onMarkPaid: () -> Void

    private var currencyCode: String {
        occurrence.currencyCode
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(occurrence.name)
                    .font(.headline)
                Text(occurrence.amount, format: .currency(code: currencyCode))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(String(localized: "Mark Paid")) {
                onMarkPaid()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(.vertical, DesignSystem.Spacing.small)
    }
}
