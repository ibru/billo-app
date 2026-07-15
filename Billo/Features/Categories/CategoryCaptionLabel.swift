//  Created by Jiri Urbasek on 07/09/26.

import SwiftUI

/// Caption-sized category label (tinted icon + secondary name) shared by
/// calendar-style rows.
///
/// Deliberately carries no `.replayMaskSensitive()` of its own: it appears
/// once per row in scrolling lists, and per-row masks were profiled as the
/// dominant scrolling-hang cost (each injects PostHog tag UIViews that
/// re-walk the view hierarchy). Every consumer must sit inside a
/// container-level replay mask — today that's the calendar list in
/// `BillsCalendarView`.
struct CategoryCaptionLabel: View {
    let info: CategoryDisplayInfo

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: info.systemImageName)
                .foregroundStyle(info.color)

            Text(info.name)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}
