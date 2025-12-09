//  Created by Jiri Urbasek on 12/09/25.

import SwiftUI

struct CurrencyRow: View {
    let currency: CurrencyItem
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(currency.name)
                    .font(.body)
                Text(currency.code)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(currency.symbol)
                .font(.body)
                .foregroundStyle(.secondary)

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(currency.name), \(currency.code)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
