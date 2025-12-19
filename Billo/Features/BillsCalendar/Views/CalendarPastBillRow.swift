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
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let info = categoryInfo {
                    HStack(spacing: 6) {
                        Image(systemName: DesignSystem.Icon.categoryIcon(for: info.iconToken))
                        Text(info.name)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.small / 2) {
                Text(display.occurrence.amount, format: .currency(code: display.occurrence.currencyCode))
                    .font(.subheadline)
                    .foregroundStyle(.primary)

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
                return "\(display.occurrence.name), paid \(formattedAmount) on \(lastDate.formatted(.dateTime.month(.wide).day().year()))"
            }
            return "\(display.occurrence.name), paid \(formattedAmount)"

        case .partiallyPaid(let paid, let remaining):
            let paidString = paid.formatted(.currency(code: display.occurrence.currencyCode))
            let remainingString = remaining.formatted(.currency(code: display.occurrence.currencyCode))
            return "\(display.occurrence.name), partially paid, \(paidString) of \(formattedAmount), remaining \(remainingString)"

        case .missed:
            let dueString = display.occurrence.dueDate.formatted(.dateTime.month(.wide).day().year())
            return "Missed: \(display.occurrence.name), \(formattedAmount), was due \(dueString)"
        }
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
}
