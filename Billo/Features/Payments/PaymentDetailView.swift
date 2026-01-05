//  Created by Jiri Urbasek on 12/05/25.

import SwiftData
import SwiftUI

struct PaymentDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var payment: Payment

    @State private var showDeleteConfirmation = false

    private var currencyCode: String {
        payment.bill?.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        Form {
            Section("Payment") {
                HStack {
                    Text("Amount")
                    Spacer()
                    Text(payment.amount, format: .currency(code: currencyCode))
                        .foregroundStyle(.green)
                }

                HStack {
                    Text("Paid on")
                    Spacer()
                    Text(payment.datePaid, format: .dateTime.month().day().year())
                        .foregroundStyle(.secondary)
                }

                if let confirmation = payment.confirmationNumber, !confirmation.isEmpty {
                    HStack {
                        Text("Confirmation")
                        Spacer()
                        Text(confirmation)
                            .foregroundStyle(.secondary)
                    }
                }

                if let notes = payment.notes, !notes.isEmpty {
                    Text(notes)
                        .foregroundStyle(.secondary)
                }
            }

            if let bill = payment.bill {
                Section("Bill") {
                    Text(bill.name)
                    Text("Due date: \(bill.dueDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Payment", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Payment")
        .platformInlineNavigationTitle()
        .confirmationDialog(
            "Delete Payment",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deletePayment()
            }
        } message: {
            Text("Are you sure you want to delete this payment? This action cannot be undone.")
        }
    }

    private func deletePayment() {
        modelContext.delete(payment)
        dismiss()
    }
}
