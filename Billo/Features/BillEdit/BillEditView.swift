//  Created by Jiri Urbasek on 11/26/25.

import SwiftUI
import SwiftData

struct BillEditView: View {
    @Environment(BillsModel.self) private var billsModel
    @Environment(AppSettingsModel.self) private var appSettingsModel
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \CustomCategory.name) private var customCategories: [CustomCategory]

    enum Mode {
        case adding
        case editing(Bill)
    }

    let mode: Mode

    @State private var name: String = ""
    @State private var amount: Decimal = 0
    @State private var dueDate: Date = Date()
    @State private var selectedCategoryIdentifier: CategoryIdentifier?
    @State private var notes: String = ""
    @State private var accountIdentifier: String = ""
    @State private var providerURL: String = ""
    @State private var isSaving: Bool = false
    @State private var saveErrorMessage: String?

    @State private var selectedRecurrencePreset: RecurrencePreset = .none
    @State private var draftSelectedIntervalType: RepeatIntervalType = .monthly
    @State private var draftFrequency: Int = 1
    @State private var draftDayOfWeek: Weekday = .monday
    @State private var draftDayOfMonth: Int = 1
    @State private var draftSelectedEndConditionType: EndConditionType = .never
    @State private var draftEndDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    init(mode: Mode) {
        self.mode = mode

        if case .editing(let bill) = mode {
            _name = State(initialValue: bill.name)
            _amount = State(initialValue: bill.amount)
            _dueDate = State(initialValue: bill.dueDate)
            _selectedCategoryIdentifier = State(initialValue: bill.categoryIdentifier)
            _notes = State(initialValue: bill.notes ?? "")
            _accountIdentifier = State(initialValue: bill.accountIdentifier ?? "")
            _providerURL = State(initialValue: bill.providerURL ?? "")
            _selectedRecurrencePreset = State(initialValue: bill.recurrenceRule?.matchingPreset ?? .none)

            if let rule = bill.recurrenceRule {
                _draftSelectedIntervalType = State(initialValue: rule.pattern)
                _draftFrequency = State(initialValue: rule.frequency)
                _draftDayOfWeek = State(initialValue: rule.dayOfWeek ?? .monday)
                _draftDayOfMonth = State(initialValue: rule.dayOfMonth ?? 1)
                _draftSelectedEndConditionType = State(initialValue: rule.endConditionType)
                _draftEndDate = State(initialValue: rule.endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
            }
        }
    }

    private var globalCurrencyCode: String {
        appSettingsModel.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)

                    LabeledContent("Amount") {
                        TextField("Amount", value: $amount, format: .number)
                            .multilineTextAlignment(.trailing)
                            .platformDecimalKeyboard()
                    }

                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)

                    Picker("Category", selection: $selectedCategoryIdentifier) {
                        Text("None").tag(nil as CategoryIdentifier?)
                        ForEach(categoryOptions) { option in
                            HStack {
                                Image(systemName: DesignSystem.Icon.categoryIcon(for: option.iconToken))
                                    .foregroundStyle(DesignSystem.Color.categoryColor(for: option.colorToken))
                                Text(option.name)
                            }
                            .tag(option.id as CategoryIdentifier?)
                        }
                    }
                }

                Section(String(localized: "Repeat")) {
                    RecurrencePresetPicker(
                        selectedPreset: $selectedRecurrencePreset,
                        intervalType: $draftSelectedIntervalType,
                        frequency: $draftFrequency,
                        dayOfWeek: $draftDayOfWeek,
                        dayOfMonth: $draftDayOfMonth,
                        anchorDate: $dueDate
                    )

                    if selectedRecurrencePreset != .none {
                        Picker("End Condition", selection: $draftSelectedEndConditionType) {
                            Text("Never").tag(EndConditionType.never)
                            Text("On Date").tag(EndConditionType.endDate)
                        }

                        if draftSelectedEndConditionType == .endDate {
                            DatePicker("End Date", selection: $draftEndDate, in: dueDate..., displayedComponents: .date)
                        }
                    }
                }

                Section("Optional Details") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)

                    TextField("Account ID", text: $accountIdentifier)

                    TextField("Provider URL", text: $providerURL)
                        .platformURLKeyboard()
                        .platformNeverAutocapitalization()
                }
            }
            .navigationTitle(mode.title)
            .platformInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.isEmpty || amount <= 0 || isSaving)
                }
            }
            .alert("Error", isPresented: .constant(saveErrorMessage != nil)) {
                Button("OK") {
                    saveErrorMessage = nil
                }
            } message: {
                if let saveErrorMessage {
                    Text(saveErrorMessage)
                }
            }
        }
    }

    private func save() {
        guard isSaving == false else { return }
        isSaving = true
        saveErrorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                switch mode {
                case .adding:
                    let bill = Bill(
                        name: name,
                        amount: amount,
                        currencyCode: globalCurrencyCode,
                        dueDate: dueDate,
                        notes: notes.isEmpty ? nil : notes,
                        accountIdentifier: accountIdentifier.isEmpty ? nil : accountIdentifier,
                        providerURL: providerURL.isEmpty ? nil : providerURL,
                        categoryIdentifier: selectedCategoryIdentifier
                    )
                    bill.recurrenceRule = buildRecurrenceRule()

                    try await billsModel.addBill(bill)

                case .editing(let bill):
                    let preEditSnapshot = BillSnapshot(bill: bill)
                    bill.name = name
                    bill.amount = amount
                    bill.dueDate = dueDate
                    bill.notes = notes.isEmpty ? nil : notes
                    bill.accountIdentifier = accountIdentifier.isEmpty ? nil : accountIdentifier
                    bill.providerURL = providerURL.isEmpty ? nil : providerURL
                    bill.categoryIdentifier = selectedCategoryIdentifier
                    bill.lastUpdatedDate = Date()

                    bill.recurrenceRule = buildRecurrenceRule()

                    try await billsModel.updateBill(bill, preEditSnapshot: preEditSnapshot)
                }

                dismiss()
            } catch {
                saveErrorMessage = error.localizedDescription
                Logger.log("Failed to save bill: \(error)", level: .error)
            }
        }
    }

    private func buildRecurrenceRule() -> RecurrenceRule? {
        selectedRecurrencePreset.buildRecurrenceRule(
            intervalType: draftSelectedIntervalType,
            frequency: draftFrequency,
            dayOfWeek: draftDayOfWeek,
            dayOfMonth: draftDayOfMonth,
            endConditionType: draftSelectedEndConditionType,
            endDate: draftEndDate
        )
    }

    private var categoryOptions: [CategoryDisplayInfo] {
        CategoryCatalog.availableCategories(customCategories: customCategories)
    }
}

extension BillEditView.Mode {
    var title: String {
        switch self {
        case .adding: return String(localized: "Add Bill")
        case .editing: return String(localized: "Edit Bill")
        }
    }
}

#Preview("Add Bill") {
    let preview = BilloPreviewContainer.withSampleData()

    return NavigationStack {
        BillEditView(mode: .adding)
            .billoPreviewEnvironment(preview)
    }
}

#Preview("Edit Bill") {
    let preview = BilloPreviewContainer.withSampleData()
    let bill = preview.bills.first ?? Bill(
        name: "Preview Bill",
        amount: 120,
        dueDate: Date()
    )

    return NavigationStack {
        BillEditView(mode: .editing(bill))
            .billoPreviewEnvironment(preview)
    }
}
