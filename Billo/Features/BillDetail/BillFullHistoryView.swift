//  Created by Jiri Urbasek on 04/03/26.

import SwiftUI
import SwiftData

struct BillFullHistoryView: View {
    @Environment(BillModel.self) private var billModel
    @Environment(BillsModel.self) private var billsModel

    let bill: Bill

    @State private var futureMonths = 12

    private var timelineEntries: [BillTimelineEntry] {
        BillTimelineBuilder.build(
            payments: billModel.paymentsSortedDescending,
            fallbackCurrencyCode: billModel.currencyCode,
            futureDates: futureDates,
            calendar: .current
        )
    }

    private var futureDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let horizon = calendar.date(byAdding: .month, value: futureMonths, to: today) ?? today
        if bill.recurrenceRule != nil {
            return bill.generateOccurrences(from: today, until: horizon, calendar: calendar)
        } else if bill.dueDate >= today && bill.dueDate < horizon {
            return [bill.dueDate]
        }
        return []
    }

    var body: some View {
        List {
            Section {
                Text(billModel.name)
                    .font(.title3)
                    .replayMaskSensitive()
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if timelineEntries.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock",
                    description: Text("No occurrences or payments to display.")
                )
            } else {
                Section {
                    ForEach(timelineEntries) { entry in
                        switch entry {
                        case .paid(let paid):
                            paidRow(paid)
                                .swipeActions(edge: .trailing) {
                                    if let payment = paid.payment {
                                        Button(role: .destructive) {
                                            deletePayment(payment)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                        case .upcoming(let date):
                            upcomingRow(date)
                        }
                    }
                }

                if bill.recurrenceRule != nil {
                    Button {
                        futureMonths += 12
                    } label: {
                        Label("Show 12 More Months", systemImage: "calendar.badge.plus")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.extraSmall)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    // Compensate for the extra inset that .insetGrouped applies to
                    // listRowBackground(.clear) rows, so the button aligns with the
                    // grouped section above it.
                    .listRowInsets(EdgeInsets(top: DesignSystem.Spacing.small, leading: 0, bottom: DesignSystem.Spacing.small, trailing: 0))
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(DesignSystem.Spacing.small)
        .contentMargins(.top, DesignSystem.Spacing.small, for: .scrollContent)
        .navigationTitle("History")
        .platformInlineNavigationTitle()
        .analyticsScreen(.billFullHistory)
    }

    @ViewBuilder
    private func paidRow(_ entry: BillTimelinePaidEntry) -> some View {
        HStack(spacing: DesignSystem.Spacing.mediumSmall) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(DesignSystem.Color.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.occurrenceDate, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
                    .font(.subheadline)

                if let confirmation = entry.confirmationNumber, !confirmation.isEmpty {
                    Text("Ref: \(confirmation)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(entry.amount.formattedAsCurrency(code: entry.currencyCode))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignSystem.Color.green)
        }
        .replayMaskSensitive()
    }

    @ViewBuilder
    private func upcomingRow(_ date: Date) -> some View {
        HStack(spacing: DesignSystem.Spacing.mediumSmall) {
            Image(systemName: "calendar")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
                    .font(.subheadline)

                Text(billModel.amount.formattedAsCurrency(code: billModel.currencyCode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
        .replayMaskSensitive()
    }

    // MARK: - Helpers

    private func daysUntilDate(_ date: Date) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: today, to: target).day ?? 0
    }

    private func deletePayment(_ payment: PaymentEntry) {
        Task {
            do {
                try await billsModel.deletePaymentEntry(payment)
            } catch {
                Logger.log("Failed to delete payment: \(error)", level: .error)
            }
        }
    }
}

// MARK: - Timeline Builder

nonisolated struct BillTimelinePaidEntry {
    let occurrenceDate: Date
    let paidDate: Date
    let amount: Decimal
    let currencyCode: String
    let confirmationNumber: String?
    let stableID: String
    let payment: PaymentEntry?
}

nonisolated enum BillTimelineEntry: Identifiable {
    case paid(BillTimelinePaidEntry)
    case upcoming(Date)

    var id: String {
        switch self {
        case .paid(let entry):
            return "paid-\(entry.stableID)"
        case .upcoming(let date):
            return "upcoming-\(date.timeIntervalSinceReferenceDate)"
        }
    }

    var sortDate: Date {
        switch self {
        case .paid(let entry): entry.occurrenceDate
        case .upcoming(let date): date
        }
    }

    var isPaid: Bool {
        if case .paid = self { return true }
        return false
    }
}

nonisolated enum BillTimelineBuilder {
    nonisolated struct PaymentInput {
        let occurrenceDate: Date
        let paidDate: Date
        let amount: Decimal
        let expectedAmount: Decimal
        let currencyCode: String
        let confirmationNumber: String?
        let stableID: String
        let payment: PaymentEntry?

        init(
            occurrenceDate: Date,
            paidDate: Date,
            amount: Decimal,
            expectedAmount: Decimal = 0,
            currencyCode: String,
            confirmationNumber: String? = nil,
            stableID: String = UUID().uuidString,
            payment: PaymentEntry? = nil
        ) {
            self.occurrenceDate = occurrenceDate
            self.paidDate = paidDate
            self.amount = amount
            self.expectedAmount = expectedAmount
            self.currencyCode = currencyCode
            self.confirmationNumber = confirmationNumber
            self.stableID = stableID
            self.payment = payment
        }
    }

    static func build(
        payments: [PaymentEntry],
        fallbackCurrencyCode: String,
        futureDates: [Date],
        calendar: Calendar
    ) -> [BillTimelineEntry] {
        let inputs = payments.map { payment in
            let expected = payment.issuedOccurrence?.billAmount ?? payment.amount
            return PaymentInput(
                occurrenceDate: payment.occurrenceDate,
                paidDate: payment.datePaid,
                amount: payment.amount,
                expectedAmount: expected,
                currencyCode: payment.snapshotCurrencyCode ?? fallbackCurrencyCode,
                confirmationNumber: payment.confirmationNumber,
                stableID: "\(payment.persistentModelID.hashValue)",
                payment: payment
            )
        }
        return build(paymentInputs: inputs, futureDates: futureDates, calendar: calendar)
    }

    static func build(
        paymentInputs: [PaymentInput],
        futureDates: [Date],
        calendar: Calendar
    ) -> [BillTimelineEntry] {
        // Sum total paid per occurrence to determine if fully paid
        var paidTotals: [Date: Decimal] = [:]
        var expectedAmounts: [Date: Decimal] = [:]
        var entries: [BillTimelineEntry] = []

        for input in paymentInputs {
            let occurrenceDate = calendar.startOfDay(for: input.occurrenceDate)
            paidTotals[occurrenceDate, default: 0] += input.amount
            expectedAmounts[occurrenceDate] = input.expectedAmount

            entries.append(.paid(BillTimelinePaidEntry(
                occurrenceDate: occurrenceDate,
                paidDate: input.paidDate,
                amount: input.amount,
                currencyCode: input.currencyCode,
                confirmationNumber: input.confirmationNumber,
                stableID: input.stableID,
                payment: input.payment
            )))
        }

        // Only suppress upcoming entries for fully paid occurrences
        let fullyPaidDates: Set<Date> = Set(
            paidTotals.compactMap { date, total in
                let expected = expectedAmounts[date] ?? 0
                return total >= expected && expected > 0 ? date : nil
            }
        )

        for date in futureDates {
            let normalized = calendar.startOfDay(for: date)
            if !fullyPaidDates.contains(normalized) {
                entries.append(.upcoming(normalized))
            }
        }

        entries.sort { $0.sortDate < $1.sortDate }

        return entries
    }
}

// MARK: - Previews

#Preview("With Payments") {
    let preview = BilloPreviewContainer.withSampleData()
    let bill = preview.bills.last ?? Bill(name: "Preview", amount: 100, dueDate: Date())

    return NavigationStack {
        BillFullHistoryView(bill: bill)
            .environment(preview.billModel(for: bill))
            .billoPreviewEnvironment(preview)
    }
}

#Preview("Recurring Bill") {
    let preview = BilloPreviewContainer.withSampleData()
    let bill = preview.bills.first(where: { $0.recurrenceRule != nil }) ?? Bill(name: "Preview", amount: 100, dueDate: Date())

    return NavigationStack {
        BillFullHistoryView(bill: bill)
            .environment(preview.billModel(for: bill))
            .billoPreviewEnvironment(preview)
    }
}
