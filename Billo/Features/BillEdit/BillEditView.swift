//  Created by Jiri Urbasek on 11/26/25.

import SwiftUI
import SwiftData

struct BillEditView: View {
    @Environment(BillsModel.self) private var billsModel
    @Environment(\.modelContext) private var modelContext
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
    @State private var currencyCode: String = Locale.current.currency?.identifier ?? "USD"

    @State private var isRepeating: Bool = false
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
            _currencyCode = State(initialValue: bill.currencyCode)
            _isRepeating = State(initialValue: bill.recurrenceRule != nil)

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

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)

                    LabeledContent("Amount") {
                        TextField("Amount", value: $amount, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }

                    Picker("Currency", selection: $currencyCode) {
                        ForEach(commonCurrencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
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

                Section("Recurrence") {
                    Toggle("Repeat", isOn: $isRepeating)
                        .onChange(of: isRepeating) { _, newValue in
                            if newValue {
                                anchorRepeatFieldsToDueDate()
                            }
                        }

                    if isRepeating {
                        RepeatIntervalPicker(
                            selectedIntervalType: $draftSelectedIntervalType,
                            frequency: $draftFrequency,
                            dayOfWeek: $draftDayOfWeek,
                            dayOfMonth: $draftDayOfMonth,
                            dueDate: dueDate
                        )

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
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
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
                    .disabled(name.isEmpty || amount <= 0)
                }
            }
            .onChange(of: dueDate) { _, _ in
                if isRepeating {
                    anchorRepeatFieldsToDueDate()
                }
            }
            .onChange(of: draftSelectedIntervalType) { _, _ in
                anchorRepeatFieldsToDueDate()
            }
        }
    }

    private func save() {
        switch mode {
        case .adding:
            let bill = Bill(
                name: name,
                amount: amount,
                currencyCode: currencyCode,
                dueDate: dueDate,
                notes: notes.isEmpty ? nil : notes,
                accountIdentifier: accountIdentifier.isEmpty ? nil : accountIdentifier,
                providerURL: providerURL.isEmpty ? nil : providerURL,
                categoryIdentifier: selectedCategoryIdentifier
            )

            if isRepeating {
                bill.recurrenceRule = buildRecurrenceRule()
            }

            modelContext.insert(bill)

        case .editing(let bill):
            bill.name = name
            bill.amount = amount
            bill.currencyCode = currencyCode
            bill.dueDate = dueDate
            bill.notes = notes.isEmpty ? nil : notes
            bill.accountIdentifier = accountIdentifier.isEmpty ? nil : accountIdentifier
            bill.providerURL = providerURL.isEmpty ? nil : providerURL
            bill.categoryIdentifier = selectedCategoryIdentifier
            bill.lastUpdatedDate = Date()

            if isRepeating {
                bill.recurrenceRule = buildRecurrenceRule()
            } else {
                bill.recurrenceRule = nil
            }
        }

        do {
            try modelContext.save()
            try billsModel.refresh()
            dismiss()
        } catch {
            print("Failed to save bill: \(error)")
        }
    }

    private func buildRecurrenceRule() -> RecurrenceRule {
        RecurrenceRule(
            pattern: draftSelectedIntervalType,
            frequency: draftFrequency,
            dayOfWeek: draftSelectedIntervalType == .weekly ? draftDayOfWeek : nil,
            dayOfMonth: draftSelectedIntervalType == .monthly ? draftDayOfMonth : nil,
            endConditionType: draftSelectedEndConditionType,
            endDate: draftSelectedEndConditionType == .endDate ? draftEndDate : nil
        )
    }

    private func anchorRepeatFieldsToDueDate() {
        let calendar = Calendar.current
        switch draftSelectedIntervalType {
        case .weekly:
            let weekday = calendar.component(.weekday, from: dueDate)
            draftDayOfWeek = Weekday.fromCalendarWeekday(weekday) ?? .monday
        case .monthly:
            draftDayOfMonth = calendar.component(.day, from: dueDate)
        case .daily, .yearly:
            break
        }
    }

    private var categoryOptions: [CategoryDisplayInfo] {
        CategoryCatalog.availableCategories(customCategories: customCategories)
    }
}

extension BillEditView.Mode {
    var title: String {
        switch self {
        case .adding: return "Add Bill"
        case .editing: return "Edit Bill"
        }
    }
}

private let commonCurrencies = [
    "USD", "EUR", "GBP", "JPY", "CNY", "CHF", "AUD", "CAD", "NZD", "SEK",
    "NOK", "DKK", "PLN", "CZK", "HUF", "RON", "BGN", "HRK", "RUB", "TRY",
    "BRL", "MXN", "ARS", "CLP", "COP", "PEN", "ZAR", "INR", "KRW", "SGD",
    "HKD", "TWD", "THB", "MYR", "PHP", "IDR", "VND", "ILS", "SAR", "AED"
]

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
