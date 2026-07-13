//  Created by Jiri Urbasek on 1/20/26.

import SwiftUI

struct RecurrencePresetPicker: View {
    @Environment(StoreKitManager.self) private var storeKit

    @Binding var selectedPreset: RecurrencePreset

    @Binding var intervalType: RepeatIntervalType
    @Binding var frequency: Int
    @Binding var dayOfWeek: Weekday
    @Binding var dayOfMonth: Int

    @Binding var anchorDate: Date

    var synchronizer: DateAnchorSynchronizer = DateAnchorSynchronizer()
    /// Fired when a non-pro user selects Custom; the host presents the paywall.
    var onCustomLocked: () -> Void = {}

    /// Captured once per view identity (form session). A bill/income that
    /// already HAS a custom rule — created while Pro, or synced from another
    /// device — keeps full Custom access for the whole edit session, so a
    /// lapsed subscription can never lock a user out of saving their own data.
    /// Only *newly choosing* Custom is gated.
    @State private var initialPresetWasCustom: Bool

    /// One-shot marker for the programmatic revert of a locked Custom
    /// selection, so its `onChange` echo is skipped exactly — a heuristic on
    /// the old value would also swallow a legitimate Custom → other transition
    /// after a mid-session entitlement lapse.
    @State private var isRevertingLockedCustom: Bool = false

    init(
        selectedPreset: Binding<RecurrencePreset>,
        intervalType: Binding<RepeatIntervalType>,
        frequency: Binding<Int>,
        dayOfWeek: Binding<Weekday>,
        dayOfMonth: Binding<Int>,
        anchorDate: Binding<Date>,
        synchronizer: DateAnchorSynchronizer = DateAnchorSynchronizer(),
        onCustomLocked: @escaping () -> Void = {}
    ) {
        _selectedPreset = selectedPreset
        _intervalType = intervalType
        _frequency = frequency
        _dayOfWeek = dayOfWeek
        _dayOfMonth = dayOfMonth
        _anchorDate = anchorDate
        self.synchronizer = synchronizer
        self.onCustomLocked = onCustomLocked
        _initialPresetWasCustom = State(initialValue: selectedPreset.wrappedValue == .custom)
    }

    private var isCustomUnlocked: Bool {
        FreeTierLimits.canSelectCustomRecurrence(isPro: storeKit.isPro) || initialPresetWasCustom
    }

    var body: some View {
        Picker(String(localized: "Repeat"), selection: $selectedPreset) {
            Text(RecurrencePreset.none.displayName).tag(RecurrencePreset.none)
            Text(RecurrencePreset.weekly.displayName).tag(RecurrencePreset.weekly)
            Text(RecurrencePreset.biweekly.displayName).tag(RecurrencePreset.biweekly)
            Text(RecurrencePreset.monthly.displayName).tag(RecurrencePreset.monthly)
            Divider()
            if isCustomUnlocked {
                Text(RecurrencePreset.custom.displayName).tag(RecurrencePreset.custom)
            } else {
                Label(RecurrencePreset.custom.displayName, systemImage: "lock.fill")
                    .tag(RecurrencePreset.custom)
            }
        }
        .pickerStyle(.menu)
        .tint(.secondary)
        .onAppear {
            anchorRepeatFieldsIfNeeded()
        }
        .onChange(of: selectedPreset) { oldValue, newValue in
            if newValue == .custom, !isCustomUnlocked {
                isRevertingLockedCustom = true
                selectedPreset = oldValue
                onCustomLocked()
                return
            }
            // Echo of the locked-Custom revert above: .custom was never
            // legitimately active, so don't let applyPresetChange treat it as
            // a real transition and mutate the draft interval fields.
            if isRevertingLockedCustom {
                isRevertingLockedCustom = false
                return
            }
            applyPresetChange(from: oldValue, to: newValue)
        }
        .onChange(of: anchorDate) { _, _ in
            anchorRepeatFieldsIfNeeded()
        }
        .onChange(of: intervalType) { _, _ in
            anchorRepeatFieldsIfNeeded()
        }
        .onChange(of: dayOfWeek) { _, newWeekday in
            syncAnchorDateToWeekday(newWeekday)
        }
        .onChange(of: dayOfMonth) { _, newDay in
            syncAnchorDateToDayOfMonth(newDay)
        }

        if selectedPreset == .custom {
            RepeatIntervalPicker(
                selectedIntervalType: $intervalType,
                frequency: $frequency,
                dayOfWeek: $dayOfWeek,
                dayOfMonth: $dayOfMonth
            )
        }
    }

    private func applyPresetChange(from oldValue: RecurrencePreset, to newValue: RecurrencePreset) {
        switch newValue {
        case .none:
            break

        case .weekly:
            intervalType = .weekly
            frequency = 1
            anchorRepeatFieldsIfNeeded()

        case .biweekly:
            intervalType = .weekly
            frequency = 2
            anchorRepeatFieldsIfNeeded()

        case .monthly:
            intervalType = .monthly
            frequency = 1
            anchorRepeatFieldsIfNeeded()

        case .custom:
            if oldValue == .none {
                intervalType = .monthly
                frequency = 1
                anchorRepeatFieldsIfNeeded()
            }
        }
    }

    private func anchorRepeatFieldsIfNeeded() {
        let anchored = Self.anchoredRepeatFieldValues(
            selectedPreset: selectedPreset,
            intervalType: intervalType,
            anchorDate: anchorDate,
            synchronizer: synchronizer
        )

        if let dayOfWeek = anchored.dayOfWeek {
            self.dayOfWeek = dayOfWeek
        }

        if let dayOfMonth = anchored.dayOfMonth {
            self.dayOfMonth = dayOfMonth
        }
    }

    static func anchoredRepeatFieldValues(
        selectedPreset: RecurrencePreset,
        intervalType: RepeatIntervalType,
        anchorDate: Date,
        synchronizer: DateAnchorSynchronizer
    ) -> (dayOfWeek: Weekday?, dayOfMonth: Int?) {
        guard selectedPreset != .none else {
            return (dayOfWeek: nil, dayOfMonth: nil)
        }

        switch intervalType {
        case .weekly:
            return (dayOfWeek: synchronizer.weekday(from: anchorDate), dayOfMonth: nil)
        case .monthly:
            return (dayOfWeek: nil, dayOfMonth: synchronizer.dayOfMonth(from: anchorDate))
        case .yearly:
            return (dayOfWeek: nil, dayOfMonth: nil)
        }
    }

    /// Syncs the anchor date to match the selected weekday (for weekly recurrence).
    /// Snaps forward to the next occurrence of the weekday.
    private func syncAnchorDateToWeekday(_ weekday: Weekday) {
        guard selectedPreset != .none, intervalType == .weekly else { return }

        if let newDate = synchronizer.syncDateToWeekday(anchorDate, weekday: weekday) {
            anchorDate = newDate
        }
    }

    /// Syncs the anchor date to match the selected day of month (for monthly recurrence).
    private func syncAnchorDateToDayOfMonth(_ targetDay: Int) {
        guard selectedPreset != .none, intervalType == .monthly else { return }

        if let newDate = synchronizer.syncDateToDayOfMonth(anchorDate, targetDay: targetDay) {
            anchorDate = newDate
        }
    }
}
