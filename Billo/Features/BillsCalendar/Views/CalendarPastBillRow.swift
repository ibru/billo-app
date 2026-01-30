//  Created by Jiri Urbasek on 12/19/25.

import SwiftUI

struct CalendarPastBillRow: View {
    let display: PastBillDisplay
    let customCategories: [CustomCategory]

    private var categoryInfo: CategoryDisplayInfo? {
        CategoryCatalog.displayInfo(
            for: display.occurrence.categoryIdentifier,
            customCategories: customCategories
        )
    }

    private var formattedAmount: String {
        display.occurrence.amount.formatted(.currency(code: display.occurrence.currencyCode))
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            CalendarDateStamp(date: display.occurrence.dueDate)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text(display.occurrence.name)
                    .font(.headline.weight(.bold))
                    .foregroundColor(Color(uiColor: .label))

                if let info = categoryInfo {
                    HStack(spacing: 6) {
                        Image(systemName: DesignSystem.Icon.categoryIcon(for: info.iconToken))
                            .foregroundStyle(DesignSystem.Color.categoryColor(for: info.colorToken))
                        Text(info.name)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.small / 2) {
                Text(display.occurrence.amount, format: .currency(code: display.occurrence.currencyCode))
                    .font(.subheadline)
                    .foregroundColor(Color(uiColor: .label))

                statusUnderAmountView
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch display.status {
        case .paid:
            if let lastDate = display.lastPaymentDate {
                let paidOn = lastDate.formatted(.dateTime.month(.wide).day().year())
                return String(
                    localized: "\(display.occurrence.name), paid \(formattedAmount) on \(paidOn)",
                    comment: "Accessibility: paid bill row (bill name, amount, paid date)"
                )
            }
            return String(
                localized: "\(display.occurrence.name), paid \(formattedAmount)",
                comment: "Accessibility: paid bill row without paid date (bill name, amount)"
            )

        case .partiallyPaid(let paid, let remaining):
            let paidString = paid.formatted(.currency(code: display.occurrence.currencyCode))
            let remainingString = remaining.formatted(.currency(code: display.occurrence.currencyCode))
            return String(
                localized: "\(display.occurrence.name), partially paid, \(paidString) of \(formattedAmount), remaining \(remainingString)",
                comment: "Accessibility: partially-paid bill row (bill name, paid amount, total, remaining)"
            )

        case .missed:
            let dueString = display.occurrence.dueDate.formatted(.dateTime.month(.wide).day().year())
            return String(
                localized: "Missed: \(display.occurrence.name), \(formattedAmount), was due \(dueString)",
                comment: "Accessibility: missed bill row (bill name, amount, due date)"
            )
        }
    }

    @ViewBuilder
    private var statusUnderAmountView: some View {
        switch display.status {
        case .paid:
            if let lastDate = display.lastPaymentDate {
                let paidOnDateString = lastDate.formatted(.dateTime.month(.abbreviated).day())
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignSystem.Color.green)
                    Text(String(
                        localized: "Paid on \(paidOnDateString)",
                        comment: "Calendar past bill row: paid-on label with date"
                    ))
                        .foregroundStyle(DesignSystem.Color.green)
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
                        comment: "Calendar past bill row: payment line (amount and date)"
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if payments.count > maxVisible {
                    let additionalCount = payments.count - maxVisible
                    Text(String(
                        localized: additionalCount == 1 ? "+\(additionalCount) more payment" : "+\(additionalCount) more payments",
                        comment: "Calendar past bill row: additional payments count"
                    ))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                let remainingString = remaining.formatted(.currency(code: display.occurrence.currencyCode))
                Text(String(
                    localized: "Remaining: \(remainingString)",
                    comment: "Calendar past bill row: remaining amount label"
                ))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Color.orange)
            }

        case .missed:
            let dueDateString = display.occurrence.dueDate.formatted(.dateTime.month(.abbreviated).day())
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(DesignSystem.Color.red)
                Text(String(
                    localized: "Was due \(dueDateString)",
                    comment: "Calendar past bill row: was-due label with due date"
                ))
                    .foregroundStyle(DesignSystem.Color.red)
            }
            .font(.caption)
        }
    }
}
