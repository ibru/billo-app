//  Created by Jiri Urbasek on 11/26/25.

import SwiftUI
import SwiftData

struct BillDetailView: View {
    @Environment(BillModel.self) private var billModel
    @Environment(BillsModel.self) private var billsModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomCategory.name) private var customCategories: [CustomCategory]

    @State private var showingEditSheet = false
    @State private var showingMarkPaidSheet = false
    @State private var showingDeleteConfirmation = false

    let bill: Bill

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Name", value: billModel.name)
                LabeledContent("Amount", value: formatCurrency(billModel.amount, code: billModel.currencyCode))
                LabeledContent("Due Date", value: billModel.dueDate, format: .dateTime.day().month().year())

                if let categoryInfo = categoryInfo {
                    LabeledContent("Category") {
                        HStack(spacing: DesignSystem.Spacing.small / 2) {
                            Image(systemName: DesignSystem.Icon.categoryIcon(for: categoryInfo.iconToken))
                                .foregroundStyle(DesignSystem.Color.categoryColor(for: categoryInfo.colorToken))
                            Text(categoryInfo.name)
                        }
                    }
                }

                if let notes = billModel.notes, !notes.isEmpty {
                    LabeledContent("Notes", value: notes)
                }

                if let accountIdentifier = billModel.accountIdentifier, !accountIdentifier.isEmpty {
                    LabeledContent("Account ID", value: accountIdentifier)
                }

                if let providerURL = billModel.providerURL, !providerURL.isEmpty {
                    LabeledContent("Provider URL") {
                        if let url = URL(string: providerURL) {
                            Link(providerURL, destination: url)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text(providerURL)
                        }
                    }
                }
            }

            if let recurrenceDescription = billModel.recurrenceDescription {
                Section("Recurrence") {
                    LabeledContent("Pattern", value: recurrenceDescription)

                    let nextDates = billModel.nextOccurrences(count: 3)
                    if !nextDates.isEmpty {
                        LabeledContent("Next Occurrences") {
                            VStack(alignment: .trailing, spacing: 4) {
                                ForEach(nextDates, id: \.self) { date in
                                    Text(date, style: .date)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }

            let payments = billModel.paymentsSortedDescending.prefix(10)
            if !payments.isEmpty {
                Section("Payment History") {
                    ForEach(Array(payments), id: \.persistentModelID) { payment in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Paid on \(payment.datePaid, style: .date)")
                                    .font(.subheadline)

                                if let confirmation = payment.confirmationNumber {
                                    Text("Confirmation: \(confirmation)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text(formatCurrency(payment.amount, code: billModel.currencyCode))
                                .font(.headline)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deletePayment(payment)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section {
                Button("Mark as Paid") {
                    showingMarkPaidSheet = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)

                Button("Edit Bill") {
                    showingEditSheet = true
                }
                .frame(maxWidth: .infinity)

                Button("Delete Bill", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(billModel.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditSheet) {
            BillEditView(mode: .editing(bill))
                .environment(billModel)
                .environment(billsModel)
        }
        .sheet(isPresented: $showingMarkPaidSheet) {
            MarkPaidSheet(bill: bill)
                .environment(billsModel)
        }
        .confirmationDialog("Delete Bill", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteBill()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this bill and all its payment history?")
        }
    }

    private var categoryInfo: CategoryDisplayInfo? {
        CategoryCatalog.displayInfo(for: billModel.categoryIdentifier, customCategories: customCategories)
    }

    private func deleteBill() {
        Task {
            do {
                try await billsModel.deleteBill(bill)
                dismiss()
            } catch {
                print("Failed to delete bill: \(error)")
            }
        }
    }

    private func deletePayment(_ payment: Payment) {
        do {
            try billModel.deletePayment(payment)
            try billsModel.refresh()
        } catch {
            print("Failed to delete payment: \(error)")
        }
    }

    private func formatCurrency(_ amount: Decimal, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = .autoupdatingCurrent
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}

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
                            .keyboardType(.decimalPad)
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
                                    Text("Balance: \(formatCurrency(remaining))")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
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
                }
            }
            .navigationTitle("Mark as Paid")
            .navigationBarTitleDisplayMode(.inline)
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
            // Store full candidate list for "Change" button
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
        // Reuse stored candidates (already includes auto-detected occurrence)
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
                Text("\(formatCurrency(remaining)) left")
                    .font(.caption)
                    .foregroundStyle(.orange)
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
                    confirmationNumber: confirmation
                )
                try billsModel.refresh()
                dismiss()
            } catch {
                print("Failed to mark bill as paid: \(error)")
            }
        }
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = bill.currencyCode
        formatter.locale = .autoupdatingCurrent
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}

#Preview("Upcoming Bill") {
    let preview = BilloPreviewContainer.withSampleData()
    let bill = preview.bills.first ?? Bill(
        name: "Preview Bill",
        amount: 100,
        dueDate: Date()
    )

    return NavigationStack {
        BillDetailView(bill: bill)
            .environment(preview.billModel(for: bill))
            .billoPreviewEnvironment(preview)
    }
}

#Preview("Paid Bill") {
    let preview = BilloPreviewContainer.withSampleData()
    let bill = preview.bills.last ?? Bill(
        name: "Paid Preview",
        amount: 50,
        dueDate: Date()
    )

    return NavigationStack {
        BillDetailView(bill: bill)
            .environment(preview.billModel(for: bill))
            .billoPreviewEnvironment(preview)
    }
}
