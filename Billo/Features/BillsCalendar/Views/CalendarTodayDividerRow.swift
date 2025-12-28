//  Created by Jiri Urbasek on 12/19/25.

import SwiftUI

struct CalendarTodayDividerRow: View {
	    var body: some View {
	        HStack(spacing: DesignSystem.Spacing.small) {
	            line
	            Text("Today")
	                .font(.caption.weight(.semibold))
	                .foregroundStyle(.secondary)
	            line
	        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignSystem.Spacing.medium)
	        .padding(.vertical, DesignSystem.Spacing.small)
	        .background(Color.clear)
	        .accessibilityElement(children: .ignore)
	        .accessibilityLabel(Text("Today"))
	    }

    private var line: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.35))
            .frame(height: 1)
    }
}
