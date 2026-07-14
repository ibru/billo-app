//  Created by Jiri Urbasek on 7/13/26.

import SwiftUI

/// Footer under a free-tier-truncated list: tells the user how many items are
/// hidden by the display cap and routes to the paywall. Count-only — never
/// shows names or amounts of hidden items, so no `.replayMaskSensitive()`.
struct HiddenItemsPromptRow: View {
    enum ItemKind {
        case bills
        case incomes
    }

    let count: Int
    let kind: ItemKind
    let onUpgradeTapped: () -> Void

    // Copy deliberately avoids a verb after the inflected phrase — automatic
    // inflection only agrees words inside the ^[...] scope, so "N bills that
    // ARE hidden" would read wrong for count == 1 (the common income case).
    @ViewBuilder
    private var message: some View {
        switch kind {
        case .bills:
            Text(
                "^[\(count) more bills](inflect: true) hidden by the free plan.",
                comment: "Free-tier display cap footer: count of hidden bills (automatic plural inflection)"
            )
        case .incomes:
            Text(
                "^[\(count) more incomes](inflect: true) hidden by the free plan.",
                comment: "Free-tier display cap footer: count of hidden incomes (automatic plural inflection)"
            )
        }
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.extraSmall) {
            message
                .foregroundStyle(.secondary)

            Button(action: onUpgradeTapped) {
                Text("Upgrade to see all", comment: "Free-tier display cap footer: upgrade call to action")
                    .fontWeight(.semibold)
                    .underline()
            }
            .buttonStyle(.plain)
            .foregroundStyle(DesignSystem.Color.green)
        }
        .font(.footnote)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.mediumSmall)
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Bills") {
    VStack {
        HiddenItemsPromptRow(count: 5, kind: .bills, onUpgradeTapped: {})
        HiddenItemsPromptRow(count: 1, kind: .incomes, onUpgradeTapped: {})
    }
}
