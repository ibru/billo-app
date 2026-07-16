//  Created by Jiri Urbasek on 7/10/26.

import SwiftUI
#if targetEnvironment(macCatalyst)
import UIKit
#endif

/// Quick bill setup: a grid of common-bill chips. Tapping a chip opens a
/// small sheet pre-filled with the preset's defaults (amount, due day,
/// monthly recurrence); tapping an already-added chip reopens the sheet to
/// edit or remove the draft.
struct OnboardingBillSetupStepView: View {
    @Environment(AnalyticsModel.self) private var analytics
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let setupModel: OnboardingSetupModel
    let currencyCode: String
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var sheetPreset: OnboardingBillPreset?

    /// iPad and Mac windows (regular × regular) get two columns of larger
    /// chips — three columns of iPhone-sized chips read tiny there.
    private var isExpansiveLayout: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }

    private var columns: [GridItem] {
        [GridItem(
            .adaptive(minimum: isExpansiveLayout ? 210 : 150),
            spacing: DesignSystem.Spacing.mediumSmall
        )]
    }

    var body: some View {
        OnboardingStepContainer(
            progressIndex: OnboardingStep.billSetup.progressIndex,
            primaryTitle: "Continue",
            primaryState: setupModel.billCount > 0 ? .enabled : .disabled,
            onPrimary: onContinue,
            secondaryTitle: setupModel.billCount == 0 ? "I’ll add bills later" : nil,
            onSecondary: setupModel.billCount == 0 ? onSkip : nil
        ) {
            VStack(spacing: DesignSystem.Spacing.large) {
                VStack(spacing: DesignSystem.Spacing.small) {
                    Text("Which bills do you pay?", comment: "Onboarding bill setup title")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text(
                        "Tap to add — you can tweak everything later.",
                        comment: "Onboarding bill setup subtitle"
                    )
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }

                LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.mediumSmall) {
                    ForEach(OnboardingBillPreset.all) { preset in
                        OnboardingBillPresetChip(
                            preset: preset,
                            draft: setupModel.billDraft(for: preset.id),
                            currencyCode: currencyCode
                        ) {
                            sheetPreset = preset
                        }
                    }
                }
                .sensoryFeedback(.selection, trigger: setupModel.billCount)

                if setupModel.billCount > 0 {
                    runningTotal
                }
            }
            .frame(maxWidth: .infinity)
        }
        .sheet(item: $sheetPreset) { preset in
            OnboardingBillAdjustSheet(
                preset: preset,
                existingDraft: setupModel.billDraft(for: preset.id),
                currencyCode: currencyCode,
                firstDueDate: { setupModel.firstDueDate(forDayOfMonth: $0) },
                onSave: { amount, dueDay, recurrence in
                    let isNew = setupModel.billDraft(for: preset.id) == nil
                    setupModel.saveBill(preset: preset, amount: amount, dueDayOfMonth: dueDay, recurrence: recurrence)
                    if isNew {
                        analytics.capture(.onboardingBillPresetAdded(
                            category: CategoryIdentifier.predefined(preset.category).analyticsKey
                        ))
                    }
                },
                onRemove: {
                    setupModel.removeBill(presetID: preset.id)
                    analytics.capture(.onboardingBillPresetRemoved(
                        category: CategoryIdentifier.predefined(preset.category).analyticsKey
                    ))
                },
                done: dismissAdjustSheet
            )
            .platformPresentationDetents([.medium])
        }
    }

    /// Dismisses the adjust sheet by clearing the item binding directly. On
    /// Mac Catalyst (macOS 26) SwiftUI clears its presentation state (the
    /// binding nils, the parent re-renders, the sheet's buttons go dead) but
    /// never drives the UIKit dismissal — the dead sheet stays on screen
    /// until the app deactivates. Verified with `@Environment(\.dismiss)`,
    /// plain binding writes, and animation-disabled transactions alike, so
    /// after clearing the state we complete the teardown UIKit-side.
    private func dismissAdjustSheet() {
        #if targetEnvironment(macCatalyst)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { sheetPreset = nil }
        // Async: give SwiftUI the update pass first; on macOS versions where
        // presentation teardown works this finds nothing left to dismiss.
        DispatchQueue.main.async {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .compactMap { $0.rootViewController?.presentedViewController }
                .forEach { $0.dismiss(animated: false) }
        }
        #else
        sheetPreset = nil
        #endif
    }

    private var runningTotal: some View {
        Text(
            "^[\(setupModel.billCount) bill](inflect: true) · ~\(setupModel.estimatedMonthlyTotal, format: .currency(code: currencyCode).precision(.fractionLength(0))) / month",
            comment: "Onboarding bill setup running total, e.g. '3 bills · ~$1,350 / month'"
        )
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .contentTransition(.numericText())
        .animation(.smooth(duration: 0.3), value: setupModel.estimatedMonthlyTotal)
        .replayMaskSensitive()
    }
}

// MARK: - Chip

private struct OnboardingBillPresetChip: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let preset: OnboardingBillPreset
    let draft: OnboardingSetupModel.BillDraft?
    let currencyCode: String
    let onTap: () -> Void

    private var isSelected: Bool { draft != nil }

    /// Mirrors the grid's layout switch: larger chip contents on iPad/Mac.
    private var isExpansiveLayout: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.small) {
                Image(systemName: preset.category.systemImageName)
                    .font(.system(size: isExpansiveLayout ? 16 : 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(
                        width: isExpansiveLayout ? 34 : 28,
                        height: isExpansiveLayout ? 34 : 28
                    )
                    .background(SwiftUI.Color(hex: preset.category.colorHex), in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.name)
                        .font(isExpansiveLayout ? .body.weight(.medium) : .subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(draft?.amount ?? preset.startingAmount(for: currencyCode), format: .currency(code: currencyCode).precision(.fractionLength(0)))
                        .font(isExpansiveLayout ? .subheadline : .caption)
                        .foregroundStyle(.secondary)
                        .replayMaskSensitive()
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: isExpansiveLayout ? 20 : 16))
                        .foregroundStyle(.tint)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(isExpansiveLayout ? DesignSystem.Spacing.mediumSmall : DesignSystem.Spacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? AnyShapeStyle(DesignSystem.Color.green.opacity(0.12)) : AnyShapeStyle(.regularMaterial),
                in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(isSelected ? DesignSystem.Color.green : SwiftUI.Color.clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .animation(.smooth(duration: 0.25), value: isSelected)
        .accessibilityLabel(Text(preset.name))
        .accessibilityValue(isSelected
            ? Text("Added", comment: "Accessibility value for a selected onboarding bill chip")
            : Text("Not added", comment: "Accessibility value for an unselected onboarding bill chip"))
    }
}

// MARK: - Adjust sheet

private struct OnboardingBillAdjustSheet: View {
    let preset: OnboardingBillPreset
    let existingDraft: OnboardingSetupModel.BillDraft?
    let currencyCode: String
    /// Computes the commit-time due date for a due day — provided by
    /// `OnboardingSetupModel` so footer and commit share one clock/calendar.
    let firstDueDate: (Int) -> Date
    let onSave: (Decimal, Int, RecurrencePreset) -> Void
    let onRemove: () -> Void
    /// Dismissal callback that clears the presenting item binding directly —
    /// NOT `@Environment(\.dismiss)`: on Mac Catalyst the environment action's
    /// animated dismissal stalls until app deactivation (see
    /// `dismissAdjustSheet`).
    let done: () -> Void

    @State private var amount: Decimal
    @State private var dueDay: Int
    @State private var recurrence: RecurrencePreset

    private var isEditing: Bool { existingDraft != nil }

    init(
        preset: OnboardingBillPreset,
        existingDraft: OnboardingSetupModel.BillDraft?,
        currencyCode: String,
        firstDueDate: @escaping (Int) -> Date,
        onSave: @escaping (Decimal, Int, RecurrencePreset) -> Void,
        onRemove: @escaping () -> Void,
        done: @escaping () -> Void
    ) {
        self.preset = preset
        self.existingDraft = existingDraft
        self.currencyCode = currencyCode
        self.firstDueDate = firstDueDate
        self.onSave = onSave
        self.onRemove = onRemove
        self.done = done
        _amount = State(initialValue: existingDraft?.amount ?? preset.startingAmount(for: currencyCode))
        _dueDay = State(initialValue: existingDraft?.dueDayOfMonth ?? preset.defaultDueDay)
        _recurrence = State(initialValue: existingDraft?.recurrence ?? .monthly)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Amount", comment: "Onboarding bill adjust sheet field")
                        Spacer()
                        TextField("Amount", value: $amount, format: .number)
                            .platformDecimalKeyboard()
                            .multilineTextAlignment(.trailing)
                            .replayMaskSensitive()
                        Text(currencyCode)
                            .foregroundStyle(.secondary)
                    }

                    Picker(selection: $dueDay) {
                        ForEach(1...31, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
                    } label: {
                        Text("Due day of month", comment: "Onboarding bill adjust sheet field")
                    }

                    Picker(selection: $recurrence) {
                        ForEach([RecurrencePreset.monthly, .biweekly, .weekly, .none]) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    } label: {
                        Text("Repeats", comment: "Onboarding bill adjust sheet field")
                    }
                } footer: {
                    // Makes the schedule anchor visible — especially for
                    // weekly/biweekly, whose weekday is derived from this date.
                    Text(
                        "First due \(firstDueDate(dueDay), format: .dateTime.weekday(.wide).month().day())",
                        comment: "Onboarding bill adjust sheet footer showing the computed first due date"
                    )
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            onRemove()
                            done()
                        } label: {
                            Text("Remove bill", comment: "Onboarding bill adjust sheet remove button")
                                .frame(maxWidth: .infinity)
                        }
                        .destructiveTint()
                    }
                }
            }
            .navigationTitle(preset.name)
            .platformInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        done()
                    } label: {
                        Text("Cancel", comment: "Onboarding bill adjust sheet cancel button")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave(amount, dueDay, recurrence)
                        done()
                    } label: {
                        Text(
                            isEditing ? "Save" : "Add bill",
                            comment: "Onboarding bill adjust sheet confirm button"
                        )
                    }
                    .disabled(amount <= 0)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    OnboardingBillSetupStepView(
        setupModel: OnboardingSetupModel(),
        currencyCode: "USD",
        onContinue: {},
        onSkip: {}
    )
    .environment(AnalyticsModel())
    .tint(DesignSystem.Color.green)
}
#endif
