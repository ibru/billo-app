//  Created by Jiri Urbasek on 12/19/25.

import SwiftUI

struct CalendarBillRow: View {
    let display: BillDisplay
    let customCategories: [CustomCategory]

    private var occurrence: BillOccurrence { display.occurrence }

    private var categoryInfo: CategoryDisplayInfo? {
        CategoryCatalog.displayInfo(
            for: occurrence.categoryIdentifier,
            customCategories: customCategories
        )
    }

    private var formattedAmount: String {
        occurrence.amount.formatted(.currency(code: occurrence.currencyCode))
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            CalendarDateStamp(date: occurrence.dueDate)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text(occurrence.name)
                    .font(.headline.weight(.bold))
                    .foregroundColor(Color(uiColor: .label))

                if let info = categoryInfo {
                    CategoryCaptionLabel(info: info)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.small / 2) {
                Text(occurrence.amount, format: .currency(code: occurrence.currencyCode))
                    .font(.subheadline)
                    .foregroundColor(Color(uiColor: .label))

                statusUnderAmountView
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .replayMaskSensitive()
    }

    @ViewBuilder
    private var statusUnderAmountView: some View {
        switch display.status {
        case .upcoming:
            EmptyView()

        case .partiallyPaid(_, let remaining):
            let remainingString = remaining.formatted(.currency(code: occurrence.currencyCode))
            Text(String(
                localized: "Remaining: \(remainingString)",
                comment: "Calendar bill row: remaining amount label"
            ))
                .font(.caption)
                .foregroundStyle(DesignSystem.Color.orange)

        case .missed:
            let dueDateString = occurrence.dueDate.formatted(.dateTime.month(.abbreviated).day())
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(DesignSystem.Color.red)
                Text(String(
                    localized: "Was due \(dueDateString)",
                    comment: "Calendar bill row: was-due label with due date"
                ))
                    .foregroundStyle(DesignSystem.Color.red)
            }
            .font(.caption)
        }
    }

    private var accessibilityLabel: String {
        let dueString = occurrence.dueDate.formatted(.dateTime.month(.wide).day().year())
        switch display.status {
        case .upcoming:
            return String(
                localized: "\(occurrence.name), \(formattedAmount), due \(dueString)",
                comment: "Accessibility: unpaid bill row (bill name, amount, due date)"
            )
        case .partiallyPaid(let paid, let remaining):
            let paidString = paid.formatted(.currency(code: occurrence.currencyCode))
            let remainingString = remaining.formatted(.currency(code: occurrence.currencyCode))
            return String(
                localized: "\(occurrence.name), partially paid, \(paidString) of \(formattedAmount), remaining \(remainingString)",
                comment: "Accessibility: partially-paid bill row (bill name, paid amount, total, remaining)"
            )
        case .missed:
            return String(
                localized: "Missed: \(occurrence.name), \(formattedAmount), was due \(dueString)",
                comment: "Accessibility: missed bill row (bill name, amount, due date)"
            )
        }
    }
}
