//  Created by Jiri Urbasek on 12/05/25.

import SwiftUI

struct BillsEmptyStateView: View {
    let onAddBill: () -> Void
    var descriptionText: LocalizedStringKey = "Add your first bill to get started"

    var body: some View {
        ContentUnavailableView {
            Label("No Bills Yet", systemImage: "calendar.badge.plus")
        } description: {
            Text(descriptionText)
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
