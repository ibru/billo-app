//  Created by Jiri Urbasek on 12/05/25.

import SwiftData
import SwiftUI

struct PaymentDetailView: View {
    @Environment(BillsModel.self) private var billsModel
    @Environment(\.dismiss) private var dismiss

    @Bindable var payment: PaymentEntry

    @State private var showDeleteConfirmation = false

    private var currencyCode: String {
        payment.snapshotCurrencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        Form {
            Section("Payment") {
                HStack {
                    Text("Amount")
                    Spacer()
                    Text(payment.amount, format: .currency(code: currencyCode))
                        .foregroundStyle(DesignSystem.Color.green)
                }
                .replayMaskSensitive()

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
                    .replayMaskSensitive()
                }

                if let notes = payment.notes, !notes.isEmpty {
                    Text(notes)
                        .foregroundStyle(.secondary)
                        .replayMaskSensitive()
                }
            }

            if let billName = payment.snapshotName {
                Section("Bill") {
                    Text(billName)
                        .replayMaskSensitive()
                    Text("Due date: \(payment.occurrenceDate.formatted(date: .abbreviated, time: .omitted))")
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
        .analyticsScreen(.paymentDetail)
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
        Task {
            do {
                try await billsModel.deletePaymentEntry(payment)
                dismiss()
            } catch {
                Logger.log("Failed to delete payment: \(error)", level: .error)
            }
        }
    }
}
