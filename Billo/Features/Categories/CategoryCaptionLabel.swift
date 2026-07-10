//  Created by Jiri Urbasek on 07/09/26.

import SwiftUI

/// Caption-sized category label (tinted icon + secondary name) shared by
/// calendar-style rows.
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
