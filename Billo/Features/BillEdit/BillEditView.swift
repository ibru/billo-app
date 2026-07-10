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

    /// For recurring bills, the date the edit screen was seeded with (the next
    /// unpaid occurrence). Used to detect whether the user actually changed the date.
    private let initialSeedDueDate: Date
    /// The bill's recurrence rule as it was before editing — used to tell a genuine
    /// recurrence change apart from the picker's on-appear day re-derivation.
    private let originalRuleSnapshot: RecurrenceRuleSnapshot?

    @State private var name: String = ""
    @State private var amount: Decimal = 0
    @State private var dueDate: Date = Date()
    @State private var selectedCategoryIdentifier: CategoryIdentifier?
    @State private var notes: String = ""
    @State private var accountIdentifier: String = ""
    @State private var providerURL: String = ""
    @State private var isSaving: Bool = false
    @State private var activeAlert: BillEditAlert?

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
            // Recurring bills open on their NEXT unpaid occurrence (matching the detail
            // view), not the raw recurrence anchor. Non-recurring bills open on dueDate.
            let seedDate = bill.recurrenceRule == nil
                ? bill.dueDate
                : bill.nextDisplayDueDate(referenceDate: Date(), calendar: .current)
            self.initialSeedDueDate = seedDate
            self.originalRuleSnapshot = bill.recurrenceRule.map { RecurrenceRuleSnapshot(rule: $0) }

            _name = State(initialValue: bill.name)
            _amount = State(initialValue: bill.amount)
            _dueDate = State(initialValue: seedDate)
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
        } else {
            self.initialSeedDueDate = Date()
            self.originalRuleSnapshot = nil
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

                    CategoryQuickPicker(
                        selection: $selectedCategoryIdentifier,
                        usageCounts: billsModel.categoryUsageCounts,
                        customCategories: customCategories
                    )
                }

                Section("Repeat") {
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
            .alert(
                activeAlert?.title ?? "",
                isPresented: Binding(isPresent: $activeAlert),
                presenting: activeAlert
            ) { alert in
                alertActions(for: alert)
            } message: { alert in
                Text(alert.message)
            }
        }
    }

    @ViewBuilder
    private func alertActions(for alert: BillEditAlert) -> some View {
        switch alert {
        case .saveError:
            Button("OK", role: .cancel) { activeAlert = nil }
        case .rescheduleWarning:
            Button("Reschedule Anyway", role: .destructive) {
                if case .editing(let bill) = mode {
                    performEdit(bill: bill)
                }
            }
            Button("Cancel", role: .cancel) { activeAlert = nil }
        }
    }

    private func save() {
        guard isSaving == false else { return }

        guard case .editing(let bill) = mode else {
            performAdd()
            return
        }

        // Warn before a reschedule that would strand overdue, still-owed occurrences
        // (they'd drop from forward-only discovery). No warning when nothing is stranded.
        if resolveOutcome().isScheduleChange {
            let stranded = bill.overdueUnpaidOccurrences(asOf: Date(), calendar: .current)
            if stranded.isEmpty == false {
                activeAlert = .rescheduleWarning(strandedDates: stranded)
                return
            }
        }

        performEdit(bill: bill)
    }

    /// Single source of truth for how this edit affects the schedule.
    private func resolveOutcome() -> BillEditReschedule.Outcome {
        BillEditReschedule.resolve(
            seededDueDate: initialSeedDueDate,
            editedDueDate: dueDate,
            originalRule: originalRuleSnapshot,
            candidateRule: buildRecurrenceRule(),
            calendar: .current
        )
    }

    private func performAdd() {
        guard isSaving == false else { return }
        isSaving = true
        activeAlert = nil
        Task {
            defer { isSaving = false }
            do {
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
                dismiss()
            } catch {
                activeAlert = .saveError(error.localizedDescription)
                Logger.log("Failed to save bill: \(error)", level: .error)
            }
        }
    }

    private func performEdit(bill: Bill) {
        guard isSaving == false else { return }
        isSaving = true
        activeAlert = nil
        Task {
            defer { isSaving = false }
            do {
                // Snapshot BEFORE mutation so past-due freezing uses the OLD schedule.
                let preEditSnapshot = BillSnapshot(bill: bill)
                let outcome = resolveOutcome()

                bill.name = name
                bill.amount = amount
                bill.notes = notes.isEmpty ? nil : notes
                bill.accountIdentifier = accountIdentifier.isEmpty ? nil : accountIdentifier
                bill.providerURL = providerURL.isEmpty ? nil : providerURL
                bill.categoryIdentifier = selectedCategoryIdentifier
                bill.lastUpdatedDate = Date()

                if case .scheduleChange(let newDueDate, let newRule) = outcome {
                    // Re-anchor to the DISPLAYED date so any new schedule takes effect
                    // forward, never retroactively from the old anchor.
                    bill.dueDate = newDueDate
                    bill.recurrenceRule = newRule
                }
                // else metadata-only: leave dueDate + recurrenceRule untouched, so the
                // picker's on-appear day re-derivation can never corrupt the rule.

                try await billsModel.updateBill(bill, preEditSnapshot: preEditSnapshot)
                dismiss()
            } catch {
                activeAlert = .saveError(error.localizedDescription)
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

}

extension BillEditView.Mode {
    var title: LocalizedStringKey {
        switch self {
        case .adding: return "Add Bill"
        case .editing: return "Edit Bill"
        }
    }
}

/// Single source of alert state for the edit screen — folds the save-error alert and
/// the reschedule warning into one optional so only one alert is ever presented.
private enum BillEditAlert {
    case saveError(String)
    case rescheduleWarning(strandedDates: [Date])

    var title: LocalizedStringKey {
        switch self {
        case .saveError:
            return "Error"
        case .rescheduleWarning:
            return "Reschedule Recurring Bill?"
        }
    }

    var message: String {
        switch self {
        case .saveError(let message):
            return message
        case .rescheduleWarning(let dates):
            return BillEditReschedule.rescheduleWarningMessage(for: dates)
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
