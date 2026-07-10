//  Created by Jiri Urbasek on 04/19/26.

import SwiftUI

/// Side-by-side "Amount" and "Category" blocks used in bill and occurrence
/// detail headers. Category is omitted when unresolved (e.g. custom category
/// no longer available or no category assigned).
struct BillDetailAmountCategoryGrid: View {
    let amount: Decimal
    let currencyCode: String
    let category: CategoryDisplayInfo?

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.extraLarge) {
            amountBlock

            if let category {
                categoryBlock(category)
            }
        }
    }

    @ViewBuilder
    private var amountBlock: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            Text("Amount")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(amount.formattedAsCurrency(code: currencyCode))
                .font(.title2.bold())
        }
    }

    @ViewBuilder
    private func categoryBlock(_ category: CategoryDisplayInfo) -> some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            Text("Category")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: DesignSystem.Spacing.extraSmall) {
                Image(systemName: category.systemImageName)
                    .font(.body)
                    .foregroundStyle(category.color)

                Text(category.name)
                    .font(.title3.weight(.medium))
            }
        }
    }
}
