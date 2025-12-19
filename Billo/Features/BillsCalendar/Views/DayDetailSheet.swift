//  Created by Jiri Urbasek on 12/05/25.

import SwiftUI

struct DayDetailSheet: View {
    let dayData: CalendarDayData
    let onMarkPaid: (BillOccurrence) async -> Void

    @Environment(\.dismiss) private var dismiss

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

                if !dayData.payments.isEmpty {
                    Section(String(localized: "Paid")) {
                        ForEach(dayData.payments) { payment in
                            DaySheetPaymentRow(payment: payment)
                        }
                    }
                }

                if !dayData.pastOccurrences.isEmpty {
                    Section(String(localized: "Past")) {
                        ForEach(dayData.pastOccurrences) { display in
                            DaySheetPastOccurrenceRow(display: display)
                        }
                    }
                }

                if !dayData.occurrences.isEmpty {
                    Section(String(localized: "Due")) {
                        ForEach(dayData.occurrences) { occurrence in
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

/// Payment row showing which bill occurrence the payment is for.
private struct DaySheetPaymentRow: View {
    let payment: Payment

    private var currencyCode: String {
        payment.bill?.currencyCode ?? "USD"
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            CalendarDateStamp(date: payment.datePaid)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text(payment.bill?.name ?? String(localized: "Unknown Bill"))
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.small / 2) {
                Text(payment.amount, format: .currency(code: currencyCode))
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Text("for \(payment.occurrenceDate, format: .dateTime.month(.abbreviated).day())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.small)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let billName = payment.bill?.name ?? String(localized: "Unknown Bill")
        let amountString = payment.amount.formatted(.currency(code: currencyCode))
        let paidOn = payment.datePaid.formatted(.dateTime.month(.wide).day().year())
        let forOccurrence = payment.occurrenceDate.formatted(.dateTime.month(.wide).day().year())
        return "\(billName), paid \(amountString) on \(paidOn), for \(forOccurrence)"
    }
}

private struct DaySheetPastOccurrenceRow: View {
    let display: PastBillDisplay

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            CalendarDateStamp(date: display.occurrence.dueDate)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text(display.occurrence.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.small / 2) {
                Text(display.occurrence.amount, format: .currency(code: display.occurrence.currencyCode))
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                statusUnderAmountView
            }
        }
        .padding(.vertical, DesignSystem.Spacing.small)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var statusUnderAmountView: some View {
        switch display.status {
        case .paid:
            if let lastDate = display.lastPaymentDate {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Paid on \(lastDate, format: .dateTime.month(.abbreviated).day())")
                        .foregroundStyle(.green)
                }
                .font(.caption)
            }

        case .partiallyPaid(_, let remaining):
            let payments = display.paymentsSortedByDate
            let maxVisible = 2

            VStack(alignment: .trailing, spacing: 2) {
                ForEach(payments.prefix(maxVisible)) { payment in
                    Text("Paid \(payment.amount, format: .currency(code: display.occurrence.currencyCode)) \(payment.datePaid, format: .dateTime.month(.abbreviated).day())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if payments.count > maxVisible {
                    Text("+\(payments.count - maxVisible) more payments")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Text("Remaining: \(remaining, format: .currency(code: display.occurrence.currencyCode))")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

        case .missed:
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                Text("Was due \(display.occurrence.dueDate, format: .dateTime.month(.abbreviated).day())")
                    .foregroundStyle(.red)
            }
            .font(.caption)
        }
    }

    private var accessibilityLabel: String {
        let name = display.occurrence.name
        let amountString = display.occurrence.amount.formatted(.currency(code: display.occurrence.currencyCode))
        switch display.status {
        case .paid:
            if let lastDate = display.lastPaymentDate {
                let paidOn = lastDate.formatted(.dateTime.month(.wide).day().year())
                return "\(name), paid \(amountString) on \(paidOn)"
            }
            return "\(name), paid \(amountString)"
        case .partiallyPaid(let paid, let remaining):
            let paidString = paid.formatted(.currency(code: display.occurrence.currencyCode))
            let remainingString = remaining.formatted(.currency(code: display.occurrence.currencyCode))
            return "\(name), partially paid, \(paidString) of \(amountString), remaining \(remainingString)"
        case .missed:
            let dueString = display.occurrence.dueDate.formatted(.dateTime.month(.wide).day().year())
            return "Missed: \(name), \(amountString), was due \(dueString)"
        }
    }
}

private struct IncomeOccurrenceRow: View {
    let incomeOccurrence: IncomeOccurrence

    private var formattedAmount: String {
        incomeOccurrence.amount.formatted(.currency(code: incomeOccurrence.currencyCode))
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            CalendarDateStamp(date: incomeOccurrence.date)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text(incomeOccurrence.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Spacer()

            Text(incomeOccurrence.amount, format: .currency(code: incomeOccurrence.currencyCode))
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Color.income)
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
        HStack(spacing: DesignSystem.Spacing.small) {
            CalendarDateStamp(date: occurrence.dueDate)

            VStack(alignment: .leading, spacing: 4) {
                Text(occurrence.name)
                    .font(.headline)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.small / 2) {
                Text(occurrence.amount, format: .currency(code: currencyCode))
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Button(String(localized: "Mark Paid")) {
                    onMarkPaid()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .accessibilityLabel("Mark paid for \(occurrence.name)")
            }
        }
        .padding(.vertical, DesignSystem.Spacing.small)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let amountString = occurrence.amount.formatted(.currency(code: currencyCode))
        let dueString = occurrence.dueDate.formatted(.dateTime.month(.wide).day().year())
        return "\(occurrence.name), \(amountString), due \(dueString)"
    }
}
