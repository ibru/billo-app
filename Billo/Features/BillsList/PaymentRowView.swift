//  Created by Jiri Urbasek on 11/27/25.

import SwiftUI

struct PaymentRowView: View {
    let payment: Payment
    let customCategories: [CustomCategory]

    private var categoryInfo: CategoryDisplayInfo? {
        guard let bill = payment.bill else { return nil }
        return CategoryCatalog.displayInfo(for: bill.categoryIdentifier, customCategories: customCategories)
    }

    private var currencyCode: String {
        payment.bill?.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            categoryIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(payment.bill?.name ?? "Unknown Bill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(payment.datePaid, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(payment.amount, format: .currency(code: currencyCode))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, DesignSystem.Spacing.small / 2)
    }

    @ViewBuilder
    private var categoryIcon: some View {
        if let info = categoryInfo {
            Image(systemName: DesignSystem.Icon.categoryIcon(for: info.iconToken))
                .foregroundStyle(DesignSystem.Color.categoryColor(for: info.colorToken))
                .font(.title3)
                .frame(width: 36)
        } else {
            Color.clear
                .frame(width: 36)
        }
    }

}
