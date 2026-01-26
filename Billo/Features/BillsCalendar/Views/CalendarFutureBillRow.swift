//  Created by Jiri Urbasek on 12/19/25.

import SwiftUI

struct CalendarFutureBillRow: View {
    let occurrence: BillOccurrence
    let payments: [PaymentEntry]
    let customCategories: [CustomCategory]

    private var categoryInfo: CategoryDisplayInfo? {
        CategoryCatalog.displayInfo(
            for: occurrence.categoryIdentifier,
            customCategories: customCategories
        )
    }

    private var isPrepaid: Bool { !payments.isEmpty }

    private var formattedAmount: String {
        occurrence.amount.formatted(.currency(code: occurrence.currencyCode))
    }

    private var prepaidDate: Date? {
        payments.max { lhs, rhs in lhs.datePaid < rhs.datePaid }?.datePaid
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            CalendarDateStamp(date: occurrence.dueDate)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text(occurrence.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let info = categoryInfo {
                    Text(info.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.small / 2) {
                Text(occurrence.amount, format: .currency(code: occurrence.currencyCode))
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                if let prepaidDate {
                    let prepaidDateString = prepaidDate.formatted(.dateTime.month(.abbreviated).day())
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(String(
                            localized: "Prepaid \(prepaidDateString)",
                            comment: "Calendar row: prepaid label with payment date"
                        ))
                            .foregroundStyle(.green)
                    }
                    .font(.caption)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let dueString = occurrence.dueDate.formatted(.dateTime.month(.wide).day().year())
        if isPrepaid {
            return String(
                localized: "\(occurrence.name), prepaid, \(formattedAmount), due \(dueString)",
                comment: "Accessibility: prepaid bill row (bill name, prepaid, amount, due date)"
            )
        }
        return String(
            localized: "\(occurrence.name), \(formattedAmount), due \(dueString)",
            comment: "Accessibility: unpaid bill row (bill name, amount, due date)"
        )
    }
}
