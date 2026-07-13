//  Created by Jiri Urbasek on 7/10/26.

import SwiftUI

/// One quick income entry — enough for the summary card and cash-flow chart
/// to show something meaningful right after onboarding. Skippable.
struct OnboardingIncomeStepView: View {
    let setupModel: OnboardingSetupModel
    let currencyCode: String
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var name: String = String(localized: "Salary", comment: "Default name for onboarding income entry")
    @State private var amount: Decimal = 0
    @State private var cadence: RecurrencePreset = .monthly
    @State private var nextPayday: Date = Date()

    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0
    }

    var body: some View {
        OnboardingStepContainer(
            progressIndex: OnboardingStep.income.progressIndex,
            primaryTitle: "Continue",
            primaryState: canContinue ? .enabled : .disabled,
            onPrimary: saveAndContinue,
            secondaryTitle: "Skip for now",
            onSecondary: onSkip
        ) {
            VStack(spacing: DesignSystem.Spacing.large) {
                VStack(spacing: DesignSystem.Spacing.small) {
                    Text("What’s coming in?", comment: "Onboarding income title")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text(
                        "Add your main income and Billo shows what’s left after bills.",
                        comment: "Onboarding income subtitle"
                    )
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }

                VStack(spacing: 0) {
                    formRow {
                        // LabeledContent wraps gracefully under large Dynamic
                        // Type where a bare HStack would compress the field.
                        LabeledContent {
                            TextField("Name", text: $name)
                                .multilineTextAlignment(.trailing)
                                .replayMaskSensitive()
                        } label: {
                            Text("Name", comment: "Onboarding income field")
                        }
                    }
                    Divider()
                    formRow {
                        LabeledContent {
                            TextField("Amount", value: $amount, format: .number)
                                .platformDecimalKeyboard()
                                .multilineTextAlignment(.trailing)
                                .replayMaskSensitive()
                            Text(currencyCode)
                                .foregroundStyle(.secondary)
                        } label: {
                            Text("Amount", comment: "Onboarding income field")
                        }
                    }
                    Divider()
                    formRow {
                        // Outside a Form, a labeled Picker renders without its
                        // label — use LabeledContent + labelsHidden instead.
                        LabeledContent {
                            Picker(selection: $cadence) {
                                ForEach([RecurrencePreset.monthly, .biweekly, .weekly]) { preset in
                                    Text(preset.displayName).tag(preset)
                                }
                            } label: {
                                Text("Repeats", comment: "Onboarding income field")
                            }
                            .labelsHidden()
                        } label: {
                            Text("Repeats", comment: "Onboarding income field")
                        }
                    }
                    Divider()
                    formRow {
                        DatePicker(
                            selection: $nextPayday,
                            displayedComponents: .date
                        ) {
                            Text("Next payday", comment: "Onboarding income field")
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func formRow(@ViewBuilder content: () -> some View) -> some View {
        HStack {
            content()
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .frame(minHeight: 48)
    }

    private func saveAndContinue() {
        do {
            try setupModel.setIncome(name: name, amount: amount, cadence: cadence, nextPayday: nextPayday)
            onContinue()
        } catch {
            // canContinue mirrors the validation rules, so this should be
            // unreachable; log instead of blocking the flow.
            Logger.log("Onboarding income validation failed unexpectedly: \(error)", level: .error)
        }
    }
}

#if DEBUG
#Preview {
    OnboardingIncomeStepView(
        setupModel: OnboardingSetupModel(),
        currencyCode: "USD",
        onContinue: {},
        onSkip: {}
    )
    .tint(DesignSystem.Color.green)
}
#endif
