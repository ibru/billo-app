//  Created by Jiri Urbasek on 04/03/26.

import SwiftUI
import SwiftData

// MARK: - Recurrence Section

struct BillDetailRecurrenceSection: View {
    @Environment(BillModel.self) private var billModel
    @Environment(BillsModel.self) private var billsModel

    let bill: Bill

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let nextDates = Array(
            bill.unpaidOccurrences(aroundDate: Date(), calendar: calendar)
                .filter { calendar.startOfDay(for: $0) >= today }
                .prefix(3)
        )

        if !nextDates.isEmpty {
            VStack(spacing: 0) {
                BillDetailSectionHeader(title: "Upcoming Occurrences")

                VStack(spacing: 0) {
                    ForEach(Array(nextDates.enumerated()), id: \.element) { index, date in
                        VStack(spacing: 0) {
                            HStack {
                                Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                                    .font(.subheadline)
                                Spacer()
                                Text(daysUntilLabel(date))
                                    .font(.caption)
                                    .foregroundStyle(
                                        DesignSystem.Color.timeSpanColor(
                                            for: date,
                                            relativeTo: Date(),
                                            calendar: .current
                                        )
                                    )
                            }
                            .padding(.horizontal, DesignSystem.Spacing.medium)
                            .padding(.vertical, DesignSystem.Spacing.mediumSmall)

                            if index < nextDates.count - 1 {
                                Divider()
                                    .padding(.leading, DesignSystem.Spacing.medium)
                            }
                        }
                    }

                    Divider()
                        .padding(.leading, DesignSystem.Spacing.medium)

                    NavigationLink {
                        BillFullHistoryView(bill: bill)
                            .environment(billModel)
                            .environment(billsModel)
                    } label: {
                        HStack {
                            Text("View Full History")
                                .font(.subheadline)
                                .foregroundStyle(.tint)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.medium)
                        .padding(.vertical, DesignSystem.Spacing.mediumSmall)
                    }
                }
                .background(DesignSystem.Color.background)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous))
            }
        }
    }
}

// MARK: - Payment History Section

struct BillDetailPaymentHistorySection: View {
    @Environment(BillModel.self) private var billModel
    @Environment(BillsModel.self) private var billsModel

    let bill: Bill

    var body: some View {
        let payments = Array(billModel.paymentsSortedDescending.prefix(3))

        VStack(spacing: 0) {
            BillDetailSectionHeader(title: "Recent Payments")

            VStack(spacing: 0) {
                ForEach(Array(payments.enumerated()), id: \.element.persistentModelID) { index, payment in
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

                            Text(payment.amount.formattedAsCurrency(code: payment.snapshotCurrencyCode ?? billModel.currencyCode))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DesignSystem.Color.green)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.medium)
                        .padding(.vertical, DesignSystem.Spacing.mediumSmall)

                        if index < payments.count - 1 {
                            Divider()
                                .padding(.leading, DesignSystem.Spacing.medium)
                        }
                    }
                }

                if billModel.paymentsSortedDescending.count > 3 {
                    Divider()
                        .padding(.leading, DesignSystem.Spacing.medium)

                    NavigationLink {
                        BillFullHistoryView(bill: bill)
                            .environment(billModel)
                            .environment(billsModel)
                    } label: {
                        HStack {
                            Text("View All Payments")
                                .font(.subheadline)
                                .foregroundStyle(.tint)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.medium)
                        .padding(.vertical, DesignSystem.Spacing.mediumSmall)
                    }
                }
            }
            .background(DesignSystem.Color.background)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous))
        }
    }
}

// MARK: - Shared Helpers

struct BillDetailSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignSystem.Spacing.extraSmall)
            .padding(.bottom, DesignSystem.Spacing.small)
    }
}

func daysUntilDate(_ date: Date) -> Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let target = calendar.startOfDay(for: date)
    return calendar.dateComponents([.day], from: today, to: target).day ?? 0
}

func daysUntilLabel(_ date: Date) -> String {
    let days = daysUntilDate(date)
    if days == 0 {
        return String(localized: "Today")
    } else if days == 1 {
        return String(localized: "Tomorrow")
    } else {
        return String(localized: "in \(days) days")
    }
}
