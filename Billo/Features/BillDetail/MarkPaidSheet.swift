//  Created by Jiri Urbasek on 11/26/25.

import SwiftUI

struct MarkPaidSheet: View {
    @Environment(BillsModel.self) private var billsModel
    @Environment(\.dismiss) private var dismiss

    let bill: Bill

    @State private var amount: Decimal
    @State private var datePaid: Date = Date()
    @State private var confirmationNumber: String = ""
    @State private var selectedOccurrence: Date?
    @State private var showOccurrencePicker: Bool = false
    @State private var occurrenceCandidates: [Date] = []
    @State private var showNoneUnpaidAlert: Bool = false

    init(bill: Bill) {
        self.bill = bill
        _amount = State(initialValue: bill.amount)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Payment Details") {
                    LabeledContent("Amount") {
                        TextField("Amount", value: $amount, format: .number)
                            .multilineTextAlignment(.trailing)
                            .platformDecimalKeyboard()
                            .replayMaskSensitive()
                    }

                    DatePicker("Date Paid", selection: $datePaid, displayedComponents: .date)
                        .onChange(of: datePaid) { _, newDate in
                            detectOccurrence(for: newDate)
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

                                // Show partial payment info if exists
                                let remaining = bill.remainingBalance(for: occurrence, calendar: .current)
                                if remaining > 0 && remaining < bill.amount {
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
                        .disabled(selectedOccurrence == nil)
                }
            }
            .alert("All Bills Paid", isPresented: $showNoneUnpaidAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("All occurrences for this bill are fully paid.")
            }
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
        let totalPaid = bill.totalPaid(for: date, calendar: .current)

        HStack {
            Text(date, style: .date)
            Spacer()
            if totalPaid > 0 && remaining > 0 {
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
