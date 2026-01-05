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
	                    Section("Income") {
	                        ForEach(dayData.incomeOccurrences, id: \.id) { incomeOccurrence in
	                            IncomeOccurrenceRow(incomeOccurrence: incomeOccurrence)
	                        }
	                    }
	                }
	
	                if !dayData.payments.isEmpty {
	                    Section("Paid") {
	                        ForEach(dayData.payments) { payment in
	                            DaySheetPaymentRow(payment: payment)
	                        }
	                    }
	                }
	
	                if !dayData.pastOccurrences.isEmpty {
	                    Section("Past") {
	                        ForEach(dayData.pastOccurrences) { display in
	                            DaySheetPastOccurrenceRow(display: display)
	                        }
	                    }
	                }
	
	                if !dayData.occurrences.isEmpty {
	                    Section("Due") {
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
	                if let billName = payment.bill?.name {
	                    Text(billName)
	                        .font(.headline)
	                        .foregroundStyle(.primary)
	                } else {
	                    Text("Unknown Bill")
	                        .font(.headline)
	                        .foregroundStyle(.primary)
	                }
	            }

            Spacer()

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.small / 2) {
                Text(payment.amount, format: .currency(code: currencyCode))
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                let occurrenceDateString = payment.occurrenceDate.formatted(.dateTime.month(.abbreviated).day())
                Text(String(
                    localized: "for \(occurrenceDateString)",
                    comment: "Day details: payment row subtitle (occurrence date)"
                ))
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
        return String(
            localized: "\(billName), paid \(amountString) on \(paidOn), for \(forOccurrence)",
            comment: "Accessibility: day details payment row (bill name, amount, paid date, occurrence date)"
        )
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
                let paidOnDateString = lastDate.formatted(.dateTime.month(.abbreviated).day())
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(String(
                        localized: "Paid on \(paidOnDateString)",
                        comment: "Day details: paid status label with date"
                    ))
                        .foregroundStyle(.green)
                }
                .font(.caption)
            }

        case .partiallyPaid(_, let remaining):
            let payments = display.paymentsSortedByDate
            let maxVisible = 2

            VStack(alignment: .trailing, spacing: 2) {
                ForEach(payments.prefix(maxVisible)) { payment in
                    let paymentAmountString = payment.amount.formatted(.currency(code: display.occurrence.currencyCode))
                    let paymentDateString = payment.datePaid.formatted(.dateTime.month(.abbreviated).day())
                    Text(String(
                        localized: "Paid \(paymentAmountString) \(paymentDateString)",
                        comment: "Day details: payment line (amount and date)"
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if payments.count > maxVisible {
                    let additionalCount = payments.count - maxVisible
                    Text(String(
                        localized: additionalCount == 1 ? "+\(additionalCount) more payment" : "+\(additionalCount) more payments",
                        comment: "Day details: additional payments count"
                    ))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                let remainingString = remaining.formatted(.currency(code: display.occurrence.currencyCode))
                Text(String(
                    localized: "Remaining: \(remainingString)",
                    comment: "Day details: remaining amount label"
                ))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

        case .missed:
            let dueDateString = display.occurrence.dueDate.formatted(.dateTime.month(.abbreviated).day())
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                Text(String(
                    localized: "Was due \(dueDateString)",
                    comment: "Day details: missed status label with due date"
                ))
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
                return String(
                    localized: "\(name), paid \(amountString) on \(paidOn)",
                    comment: "Accessibility: day details paid bill row (name, amount, paid date)"
                )
            }
            return String(
                localized: "\(name), paid \(amountString)",
                comment: "Accessibility: day details paid bill row without paid date (name, amount)"
            )
        case .partiallyPaid(let paid, let remaining):
            let paidString = paid.formatted(.currency(code: display.occurrence.currencyCode))
            let remainingString = remaining.formatted(.currency(code: display.occurrence.currencyCode))
            return String(
                localized: "\(name), partially paid, \(paidString) of \(amountString), remaining \(remainingString)",
                comment: "Accessibility: day details partially-paid bill row (name, paid, total, remaining)"
            )
        case .missed:
            let dueString = display.occurrence.dueDate.formatted(.dateTime.month(.wide).day().year())
            return String(
                localized: "Missed: \(name), \(amountString), was due \(dueString)",
                comment: "Accessibility: day details missed bill row (name, amount, due date)"
            )
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
        .accessibilityLabel(String(
            localized: "Income: \(incomeOccurrence.name), \(formattedAmount)",
            comment: "Accessibility: day details income row label (name, amount)"
        ))
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
	
	                Button("Mark Paid") {
	                    onMarkPaid()
	                }
	                .buttonStyle(.borderedProminent)
	                .tint(.green)
                .accessibilityLabel(String(
                    localized: "Mark paid for \(occurrence.name)",
                    comment: "Accessibility: mark paid button (bill name)"
                ))
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
        return String(
            localized: "\(occurrence.name), \(amountString), due \(dueString)",
            comment: "Accessibility: day details due bill row (name, amount, due date)"
        )
    }
}
