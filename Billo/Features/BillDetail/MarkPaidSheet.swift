//  Created by Jiri Urbasek on 11/26/25.

import SwiftUI

struct MarkPaidSheet: View {
    @Environment(BillsModel.self) private var billsModel
    @Environment(StoreKitManager.self) private var storeKit
    @Environment(AnalyticsModel.self) private var analytics
    @Environment(\.dismiss) private var dismiss

    let bill: Bill

    @State private var amount: Decimal
    @State private var datePaid: Date = Date()
    @State private var confirmationNumber: String = ""
    @State private var selectedOccurrence: Date?
    @State private var showOccurrencePicker: Bool = false
    @State private var occurrenceCandidates: [Date] = []
    @State private var showNoneUnpaidAlert: Bool = false
    @State private var paywallContext: PaywallContext?
    @FocusState private var amountFieldFocused: Bool

    init(bill: Bill) {
        self.bill = bill
        _amount = State(initialValue: bill.amount)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Amount") {
                        TextField("Amount", value: $amount, format: .number)
                            .multilineTextAlignment(.trailing)
                            .platformDecimalKeyboard()
                            .focused($amountFieldFocused)
                            .replayMaskSensitive()
                    }

                    DatePicker("Date Paid", selection: $datePaid, displayedComponents: .date)
                        .onChange(of: datePaid) { _, newDate in
                            detectOccurrence(for: newDate)
                        }
                        .onChange(of: selectedOccurrence) { _, newOccurrence in
                            // The default amount always means "pay this
                            // occurrence in full". Seeding from the series
                            // amount instead would misread a frozen occurrence
                            // (snapshot amount diverged from the live series)
                            // as a partial payment — or silently overpay an
                            // already partially-paid one.
                            guard let newOccurrence else { return }
                            // A focused value TextField won't reformat its
                            // visible text on an external binding write —
                            // unfocus first so the screen can never show a
                            // different number than what Save records.
                            amountFieldFocused = false
                            amount = bill.remainingBalance(for: newOccurrence, calendar: .current)
                        }

                    // Occurrence selection
                    if showOccurrencePicker {
                        Picker("For Occurrence", selection: $selectedOccurrence) {
                            ForEach(occurrenceCandidates, id: \.self) { date in
                                occurrenceLabel(for: date)
                                    .tag(date as Date?)
                            }
                        }
                    } else if let occurrence = selectedOccurrence {
                        HStack {
                            Text("For Occurrence")
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(occurrence, style: .date)
                                    .foregroundStyle(.secondary)

                                // Show the true amount owed whenever it differs
                                // from the series amount (partially paid, or a
                                // frozen snapshot after a series-amount edit).
                                let remaining = bill.remainingBalance(for: occurrence, calendar: .current)
                                if remaining > 0 && remaining != bill.amount {
                                    Text("Balance: \(remaining.formattedAsCurrency(code: bill.currencyCode))")
                                        .font(.caption)
                                        .foregroundStyle(DesignSystem.Color.orange)
                                        .replayMaskSensitive()
                                }
                            }

                            Button("Change") {
                                showAllCandidates()
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                    }

                    TextField("Confirmation Number (optional)", text: $confirmationNumber)
                        .replayMaskSensitive()
                } header: {
                    Text("Payment Details")
                } footer: {
                    if !storeKit.isPro {
                        // Announce the gate before the user hits it — the
                        // paywall on Save must never feel like a surprise.
                        Label {
                            Text("Partial payments are a Pro feature", comment: "Footer hint in the mark-paid sheet for free users")
                        } icon: {
                            Image(systemName: "lock.fill")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Mark as Paid")
            .platformInlineNavigationTitle()
            .analyticsScreen(.markPaidSheet)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { markPaid() }
                        .disabled(selectedOccurrence == nil || amount <= 0)
                }
            }
            .alert("All Bills Paid", isPresented: $showNoneUnpaidAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("All occurrences for this bill are fully paid.")
            }
            .paywallSheet(context: $paywallContext)
            .onAppear {
                detectOccurrence(for: datePaid)
            }
        }
    }

    // MARK: - Detection Logic

    private func detectOccurrence(for date: Date) {
        let result = bill.detectOccurrence(for: date, calendar: .current)

        switch result {
        case .certain(let occurrence):
            selectedOccurrence = occurrence
            occurrenceCandidates = bill.unpaidOccurrences(
                aroundDate: date,
                calendar: .current
            )
            showOccurrencePicker = false

        case .ambiguous(let candidates):
            selectedOccurrence = candidates.first
            occurrenceCandidates = candidates
            showOccurrencePicker = true

        case .noneUnpaid:
            selectedOccurrence = nil
            occurrenceCandidates = []
            showOccurrencePicker = false
            showNoneUnpaidAlert = true
        }
    }

    private func showAllCandidates() {
        showOccurrencePicker = true
    }

    @ViewBuilder
    private func occurrenceLabel(for date: Date) -> some View {
        let remaining = bill.remainingBalance(for: date, calendar: .current)

        HStack {
            Text(date, style: .date)
            Spacer()
            // Same condition as the balance hint above: flag any occurrence
            // whose amount owed differs from the series amount — partially
            // paid, or frozen at a different snapshot amount.
            if remaining > 0 && remaining != bill.amount {
                Text("\(remaining.formattedAsCurrency(code: bill.currencyCode)) left")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Color.orange)
                    .replayMaskSensitive()
            }
        }
    }

    // MARK: - Actions

    private func markPaid() {
        guard let occurrenceDate = selectedOccurrence else { return }
        // Belt to the disabled button's suspenders — PaymentRecorder persists
        // whatever it receives, so never let a non-positive amount through.
        guard amount > 0 else { return }

        let remaining = bill.remainingBalance(for: occurrenceDate, calendar: .current)
        guard FreeTierLimits.canRecordPayment(
            amount: amount,
            remainingBalance: remaining,
            isPro: storeKit.isPro
        ) else {
            analytics.capture(.proGateHit(feature: PaywallContext.partialPayment.analyticsKey))
            paywallContext = .partialPayment
            return
        }

        let occurrence = BillOccurrence(bill: bill, dueDate: occurrenceDate)

        Task {
            do {
                let confirmation = confirmationNumber.isEmpty ? nil : confirmationNumber
                try await billsModel.markPaid(
                    occurrence,
                    amount: amount,
                    date: datePaid,
                    confirmationNumber: confirmation,
                    source: .sheet
                )
                // markPaid already calls refresh() internally
                dismiss()
            } catch {
                Logger.log("Failed to mark bill as paid: \(error)", level: .error)
            }
        }
    }
}
