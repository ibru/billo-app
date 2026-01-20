//  Created by Jiri Urbasek on 12/25/25.

import SwiftUI

struct FloatingPill<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .billoFloatingPillPadding()
            .billoFloatingGlassEffect()
            .background(FloatingPillHitTestBlocker())
            .buttonStyle(.plain)
    }
}

struct FloatingPillButton<Label: View>: View {
    private let action: () -> Void
    private let label: Label
    private let verticalPadding: CGFloat
    private let horizontalPadding: CGFloat

    init(
        verticalPadding: CGFloat = 4,
        horizontalPadding: CGFloat = 6,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.verticalPadding = verticalPadding
        self.horizontalPadding = horizontalPadding
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) {
            label
        }
        .billoFloatingPillPadding(
            vertical: verticalPadding,
            horizontal: horizontalPadding
        )
        .billoFloatingGlassEffect()
        .buttonStyle(.plain)
    }
}

private struct FloatingPillHitTestBlocker: View {
    var body: some View {
        Capsule()
            .fill(Color.clear)
            .contentShape(Capsule())
            .onTapGesture { }
    }
}

extension View {
    func billoFloatingPillPadding(
        vertical: CGFloat = 4,
        horizontal: CGFloat = 6
    ) -> some View {
        padding(.vertical, vertical)
            .padding(.horizontal, horizontal)
    }
}
