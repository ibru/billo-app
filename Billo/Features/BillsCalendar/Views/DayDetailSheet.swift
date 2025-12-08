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
