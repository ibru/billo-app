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
