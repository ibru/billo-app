//  Created by Jiri Urbasek on 12/05/25.

import SwiftUI

struct CalendarEmptyStateView: View {
    let onAddBill: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Bills Yet", systemImage: "calendar.badge.plus")
        } description: {
            Text("Add your first bill to see it in the calendar")
        } actions: {
            Button("Add Bill") {
                onAddBill()
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Color.yellow)
        }
        .padding()
    }
}
