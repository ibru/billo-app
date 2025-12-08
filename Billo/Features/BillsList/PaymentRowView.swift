//  Created by Jiri Urbasek on 11/27/25.

import SwiftUI

struct PaymentRowView: View {
    enum LeadingIconStyle {
        case category
        case checkmark
    }

    let payment: Payment
    let customCategories: [CustomCategory]
    var leadingIconStyle: LeadingIconStyle = .category
    var accentColor: Color? = nil
    var showsChevron: Bool = false

    private var categoryInfo: CategoryDisplayInfo? {
        guard let bill = payment.bill else { return nil }
        return CategoryCatalog.displayInfo(for: bill.categoryIdentifier, customCategories: customCategories)
    }

    private var currencyCode: String {
        payment.bill?.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    private var amountColor: Color {
        accentColor ?? Color.secondary
    }

    private var nameColor: Color {
        accentColor == nil ? .secondary : .primary
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            leadingIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(payment.bill?.name ?? String(localized: "Payment"))
                    .font(.subheadline.weight(accentColor == nil ? .regular : .semibold))
                    .foregroundStyle(nameColor)
                    .lineLimit(1)

                Text(payment.datePaid, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(payment.amount, format: .currency(code: currencyCode))
                .font(.subheadline.weight(accentColor == nil ? .regular : .semibold))
                .foregroundStyle(amountColor)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .padding(.vertical, accentColor == nil ? DesignSystem.Spacing.small / 2 : DesignSystem.Spacing.small)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(payment.amount.formatted(.currency(code: currencyCode)))
    }

    @ViewBuilder
    private var leadingIcon: some View {
        switch leadingIconStyle {
        case .category:
            if let info = categoryInfo {
                Image(systemName: DesignSystem.Icon.categoryIcon(for: info.iconToken))
                    .foregroundStyle(DesignSystem.Color.categoryColor(for: info.colorToken))
                    .font(.title3)
                    .frame(width: 36)
            } else {
                Color.clear
                    .frame(width: 36)
            }
        case .checkmark:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
                .frame(width: 36)
        }
    }

    private var accessibilityLabel: String {
        let name = payment.bill?.name ?? String(localized: "Payment")
        let dateString = payment.datePaid.formatted(.dateTime.month().day().year())
        return "\(name), paid on \(dateString)"
    }
}
