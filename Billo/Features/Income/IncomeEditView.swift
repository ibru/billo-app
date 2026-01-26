//  Created by Jiri Urbasek on 12/10/25.

import SwiftUI
import SwiftData

struct IncomeEditView: View {
    @Environment(BillsModel.self) private var billsModel
    @Environment(AppSettingsModel.self) private var appSettingsModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    enum Mode {
        case adding
        case editing(Income)
    }

    let mode: Mode

    @State private var name: String = ""
    @State private var amount: Decimal = 0
    @State private var startDate: Date = Date()

    @State private var selectedRecurrencePreset: RecurrencePreset = .monthly
    @State private var draftSelectedIntervalType: RepeatIntervalType = .monthly
    @State private var draftFrequency: Int = 1
    @State private var draftDayOfWeek: Weekday = .monday
    @State private var draftDayOfMonth: Int = 1
    @State private var draftSelectedEndConditionType: EndConditionType = .never
    @State private var draftEndDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    init(mode: Mode) {
        self.mode = mode

        if case .editing(let income) = mode {
            _name = State(initialValue: income.name)
            _amount = State(initialValue: income.amount)
            _startDate = State(initialValue: income.startDate)
            _selectedRecurrencePreset = State(initialValue: income.recurrenceRule?.matchingPreset ?? .none)

            if let rule = income.recurrenceRule {
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

                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                }

                Section(String(localized: "Repeat")) {
                    RecurrencePresetPicker(
                        selectedPreset: $selectedRecurrencePreset,
                        intervalType: $draftSelectedIntervalType,
                        frequency: $draftFrequency,
                        dayOfWeek: $draftDayOfWeek,
                        dayOfMonth: $draftDayOfMonth,
                        anchorDate: $startDate
                    )

                    if selectedRecurrencePreset != .none {
                        Picker("End Condition", selection: $draftSelectedEndConditionType) {
                            Text("Never").tag(EndConditionType.never)
                            Text("On Date").tag(EndConditionType.endDate)
                        }

                        if draftSelectedEndConditionType == .endDate {
                            DatePicker("End Date", selection: $draftEndDate, in: startDate..., displayedComponents: .date)
                        }
                    }
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
                    .disabled(name.isEmpty || amount <= 0)
                }
            }
        }
    }

    private func save() {
        switch mode {
        case .adding:
            do {
                let income = try Income.create(
                    name: name,
                    amount: amount,
                    currencyCode: globalCurrencyCode,
                    startDate: startDate,
                    recurrenceRule: buildRecurrenceRule()
                )

                modelContext.insert(income)
                try modelContext.save()
                try billsModel.refresh()
                dismiss()
            } catch {
                Logger.log("Failed to save income: \(error)", level: .error)
            }

        case .editing(let income):
            income.name = name.trimmingCharacters(in: .whitespaces)
            income.amount = amount
            income.startDate = startDate
            income.recurrenceRule = buildRecurrenceRule()
            income.lastUpdatedDate = Date()

            Task {
                try? await billsModel.updateIncome(income)
                dismiss()
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
}

extension IncomeEditView.Mode {
    var title: String {
        switch self {
        case .adding: return String(localized: "Add Income")
        case .editing: return String(localized: "Edit Income")
        }
    }
}
