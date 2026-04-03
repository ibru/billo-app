//  Created by Jiri Urbasek on 12/19/25.

import SwiftUI

/// Date stamp used as a consistent leading element in calendar rows.
/// Shows day number with abbreviated month below (lowercased).
struct CalendarDateStamp: View {
    let date: Date
    var accentColor: Color? = nil

    @ScaledMetric(relativeTo: .caption) private var width: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            Text(date, format: .dateTime.day())
                .font(.title2.weight(.bold))
                .foregroundColor(accentColor ?? Color(uiColor: .label))

            Text(date, format: .dateTime.month(.abbreviated))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accentColor?.opacity(0.8) ?? .secondary)
                .textCase(.uppercase)
        }
        .frame(width: width, alignment: .center)
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
        .accessibilityHidden(true)
    }
}

/// Compact date stamp for dividers and lightweight rows.
struct CalendarCompactDateStamp: View {
    let date: Date
    var accentColor: Color? = nil

    @ScaledMetric(relativeTo: .caption2) private var width: CGFloat = 32

    var body: some View {
        VStack(spacing: 0) {
            Text(date, format: .dateTime.day())
                .font(.headline.weight(.semibold))
                .foregroundStyle(accentColor ?? Color(uiColor: .label))

            Text(date, format: .dateTime.month(.abbreviated))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accentColor?.opacity(0.85) ?? .secondary)
                .textCase(.uppercase)
        }
        .frame(width: width, alignment: .center)
        .accessibilityHidden(true)
    }
}

/// Filled date stamp with colored rounded rectangle background and white text.
/// Used for "Today" dividers and income rows that embed the date inside a solid shape.
struct CalendarFilledDateStamp: View {
    let date: Date
    let color: Color

    @ScaledMetric(relativeTo: .caption2) private var width: CGFloat = 38

    var body: some View {
        VStack(spacing: 0) {
            Text(date, format: .dateTime.day())
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text(date, format: .dateTime.month(.abbreviated))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .textCase(.uppercase)
        }
        .frame(width: width)
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color)
        )
        .accessibilityHidden(true)
    }
}
