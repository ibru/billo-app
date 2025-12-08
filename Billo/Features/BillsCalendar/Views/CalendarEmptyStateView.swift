//  Created by Jiri Urbasek on 12/05/25.

import SwiftUI

struct CalendarEmptyStateView: View {
    let onAddBill: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(String(localized: "No Bills Yet"), systemImage: "calendar.badge.plus")
        } description: {
            Text(String(localized: "Add your first bill to see it in the calendar"))
        } actions: {
            Button(String(localized: "Add Bill")) {
                onAddBill()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
