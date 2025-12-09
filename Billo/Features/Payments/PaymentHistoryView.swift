//  Created by Jiri Urbasek on 12/09/25.

import SwiftData
import SwiftUI

struct PaymentHistoryView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Payment.datePaid, order: .reverse)
    private var allPayments: [Payment]

    @Query(sort: \CustomCategory.name)
    private var customCategories: [CustomCategory]

    @State private var displayLimit: Int = 200

    private var displayedPayments: [Payment] {
        Array(allPayments.prefix(displayLimit))
    }

    private var hasMore: Bool {
        allPayments.count > displayLimit
    }

    var body: some View {
        List {
            if allPayments.isEmpty {
                ContentUnavailableView(
                    "No Payments Yet",
                    systemImage: "checkmark.circle",
                    description: Text("Payments you make will appear here")
                )
            } else {
                ForEach(displayedPayments, id: \.persistentModelID) { payment in
                    NavigationLink(value: payment) {
                        PaymentRowView(payment: payment, customCategories: customCategories)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deletePayment(payment)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                if hasMore {
                    Button {
                        displayLimit += 200
                    } label: {
                        HStack {
                            Spacer()
                            Text("Load More")
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("Payment History")
    }

    private func deletePayment(_ payment: Payment) {
        modelContext.delete(payment)
    }
}

#Preview("Sample Data") {
    let preview = BilloPreviewContainer.withSampleData()

    return NavigationStack {
        PaymentHistoryView()
    }
    .billoPreviewEnvironment(preview)
}

#Preview("Empty State") {
    let preview = BilloPreviewContainer.empty()

    return NavigationStack {
        PaymentHistoryView()
    }
    .billoPreviewEnvironment(preview)
}
