//  Created by Jiri Urbasek on 11/27/25.

import SwiftUI

struct PaymentRowView: View {
    enum LeadingIconStyle {
        case category
        case checkmark
    }

    let payment: PaymentEntry
    let customCategories: [CustomCategory]
    var leadingIconStyle: LeadingIconStyle = .category
    var accentColor: Color? = nil
    var showsChevron: Bool = false

    private var categoryInfo: CategoryDisplayInfo? {
        guard let categoryIdentifier = payment.snapshotCategoryIdentifier else { return nil }
        return CategoryCatalog.displayInfo(for: categoryIdentifier, customCategories: customCategories)
    }

    private var currencyCode: String {
        payment.snapshotCurrencyCode ?? Locale.current.currency?.identifier ?? "USD"
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
	                if let billName = payment.snapshotName {
	                    Text(billName)
	                        .font(.subheadline.weight(accentColor == nil ? .regular : .semibold))
	                        .foregroundStyle(nameColor)
	                        .lineLimit(1)
	                } else {
	                    Text("Payment")
	                        .font(.subheadline.weight(accentColor == nil ? .regular : .semibold))
	                        .foregroundStyle(nameColor)
	                        .lineLimit(1)
	                }
	
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
                    .foregroundStyle(DesignSystem.Color.tertiaryLabel)
            }
        }
        .padding(.vertical, accentColor == nil ? DesignSystem.Spacing.small / 2 : DesignSystem.Spacing.small)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(payment.amount.formatted(.currency(code: currencyCode)))
        // Replay-masked by each hosting screen's container mask
        // (bills list ScrollView, DayDetailSheet list, PaymentHistoryView list).
    }

    @ViewBuilder
    private var leadingIcon: some View {
        switch leadingIconStyle {
        case .category:
            if let info = categoryInfo {
                Image(systemName: info.systemImageName)
                    .foregroundStyle(info.color)
                    .font(.title3)
                    .frame(width: 36)
            } else {
                Color.clear
                    .frame(width: 36)
            }
        case .checkmark:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(DesignSystem.Color.green)
                .font(.title3)
                .frame(width: 36)
        }
    }

    private var accessibilityLabel: String {
        let name = payment.snapshotName ?? String(localized: "Payment")
        let dateString = payment.datePaid.formatted(.dateTime.month().day().year())
        return String(
            localized: "\(name), paid on \(dateString)",
            comment: "Accessibility: payment row label (bill name, paid-on date)"
        )
    }
}
