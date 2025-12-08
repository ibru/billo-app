//  Created by Jiri Urbasek on 12/05/25.

import SwiftUI

struct PaymentDetailView: View {
    let payment: Payment

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
        }
        .navigationTitle("Payment")
        .navigationBarTitleDisplayMode(.inline)
    }
}
