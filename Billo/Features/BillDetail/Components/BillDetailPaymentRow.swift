//  Created by Jiri Urbasek on 04/19/26.

import SwiftUI

/// Payment row styled for bill-detail and occurrence-detail "Payments" cards.
/// Reads from the PaymentEntry snapshot so it renders correctly even when the
/// originating Bill was deleted.
struct BillDetailPaymentRow: View {
    let payment: PaymentEntry
    let fallbackCurrencyCode: String
    let isLast: Bool

    private var currencyCode: String {
        payment.snapshotCurrencyCode ?? fallbackCurrencyCode
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(payment.datePaid, format: .dateTime.month(.abbreviated).day().year())
                        .font(.subheadline)

                    if let confirmation = payment.confirmationNumber, !confirmation.isEmpty {
                        Text("Ref: \(confirmation)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(payment.amount.formattedAsCurrency(code: currencyCode))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.Color.green)
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.mediumSmall)

            if !isLast {
                Divider()
                    .padding(.leading, DesignSystem.Spacing.medium)
            }
        }
    }
}
