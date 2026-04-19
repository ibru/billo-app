//  Created by Jiri Urbasek on 04/19/26.

import SwiftUI

/// Weekday / month-day / year stack used by bill and occurrence detail headers.
struct BillDetailDueDateStack: View {
    let date: Date

    var body: some View {
        VStack(spacing: 2) {
            Text(Self.weekdayFormatter.string(from: date))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(date, format: .dateTime.month(.wide).day())
                .font(.title.bold())

            Text(date, format: .dateTime.year())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter
    }()
}
