//  Created by Jiri Urbasek on 12/05/25.

import SwiftUI

struct MonthHeaderView: View {
    let title: String
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
            }
            .disabled(!canGoBack)
            .accessibilityLabel("Previous month")

            Spacer()

            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button(action: onForward) {
                Image(systemName: "chevron.right")
            }
            .disabled(!canGoForward)
            .accessibilityLabel("Next month")
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
    }
}
