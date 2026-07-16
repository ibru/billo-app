//  Created by Jiri Urbasek on 12/10/25.

import StoreKit
import SwiftUI
import SwiftData

struct IncomeEditView: View {
    @Environment(BillsModel.self) private var billsModel
    @Environment(AppSettingsModel.self) private var appSettingsModel
    @Environment(AnalyticsModel.self) private var analytics
    @Environment(StoreKitManager.self) private var storeKit
    @Environment(ReviewPromptModel.self) private var reviewPrompts
    @Environment(\.requestReview) private var requestReview
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
    @State private var paywallContext: PaywallContext?

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

    private var analyticsScreenValue: AnalyticsScreen {
        if case .adding = mode { .incomeAdd } else { .incomeEdit }
    }

    private var globalCurrencyCode: String {
        appSettingsModel.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                        .replayMaskSensitive()

                    LabeledContent("Amount") {
                        TextField("Amount", value: $amount, format: .number)
                            .multilineTextAlignment(.trailing)
                            .platformDecimalKeyboard()
                            .replayMaskSensitive()
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
                        anchorDate: $startDate,
                        onCustomLocked: {
                            analytics.capture(.proGateHit(feature: PaywallContext.customRecurrence.analyticsKey))
                            paywallContext = .customRecurrence
                        }
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
            .analyticsScreen(analyticsScreenValue)
            .paywallSheet(context: $paywallContext)
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
                let currentCount = try billsModel.storedIncomeCount()
                if !FreeTierLimits.canAddIncome(currentCount: currentCount, isPro: storeKit.isPro) {
                    analytics.capture(.proGateHit(feature: PaywallContext.incomeLimit.analyticsKey))
                    paywallContext = .incomeLimit
                    return
                }
            } catch {
                // Stay in the form; mirrors the save-failure path below.
                Logger.log("Failed to count incomes for free-tier gate: \(error)", level: .error)
                return
            }
            Task {
                do {
                    let income = try Income.create(
                        name: name,
                        amount: amount,
                        currencyCode: globalCurrencyCode,
                        startDate: startDate,
                        recurrenceRule: buildRecurrenceRule()
                    )

                    // Centralized add path (insert + save + refresh + analytics).
                    try await billsModel.addIncome(income)
                    // addIncome refreshed the model, so totalIncomeCount is current.
                    let shouldRequestReview = reviewPrompts.noteIncomeSaved(totalIncomeCount: billsModel.totalIncomeCount)
                    dismiss()
                    if shouldRequestReview {
                        await requestReview.requestAfterSettleDelay()
                    }
                } catch {
                    // Stay in the form so the user can correct + retry. Mirrors
                    // DayDetailSheet.skipOccurrence: dismiss only on success.
                    Logger.log("Failed to save income: \(error)", level: .error)
                }
            }

        case .editing(let income):
            let draft = IncomeDraft(
                name: name.trimmingCharacters(in: .whitespaces),
                amount: amount,
                startDate: startDate,
                recurrenceRule: buildRecurrenceRule()
            )

            Task {
                do {
                    try await billsModel.updateIncome(income, draft: draft)
                    dismiss()
                } catch {
                    Logger.log("Failed to update income: \(error)", level: .error)
                }
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
