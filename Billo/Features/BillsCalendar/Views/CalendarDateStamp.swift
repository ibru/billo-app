//  Created by Jiri Urbasek on 12/19/25.

import SwiftUI

/// Date stamp used as a consistent leading element in calendar rows.
/// Shows day number with abbreviated month below (lowercased).
struct CalendarDateStamp: View {
    let date: Date

    @ScaledMetric(relativeTo: .caption) private var width: CGFloat = 36

    var body: some View {
        VStack(spacing: 0) {
            Text(date, format: .dateTime.day())
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            Text(date, format: .dateTime.month(.abbreviated))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.lowercase)
        }
        .frame(width: width, alignment: .center)
        .accessibilityHidden(true)
    }
}
