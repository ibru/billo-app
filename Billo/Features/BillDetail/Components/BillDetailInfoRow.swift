//  Created by Jiri Urbasek on 04/19/26.

import SwiftUI

/// Label + value row used inside bill/occurrence detail info cards.
struct BillDetailInfoRow: View {
    let label: LocalizedStringKey
    let value: String
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.mediumSmall)

            if !isLast {
                Divider()
                    .padding(.leading, DesignSystem.Spacing.medium)
            }
        }
        .replayMaskSensitive()
    }
}

/// Rounded-corner card background applied to grouped info/payment sections.
struct BillDetailCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0, content: content)
            .background(DesignSystem.Color.background)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous))
    }
}
