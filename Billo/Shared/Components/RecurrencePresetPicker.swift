//  Created by Jiri Urbasek on 1/20/26.

import SwiftUI

struct RecurrencePresetPicker: View {
    @Binding var selectedPreset: RecurrencePreset

    @Binding var intervalType: RepeatIntervalType
    @Binding var frequency: Int
    @Binding var dayOfWeek: Weekday
    @Binding var dayOfMonth: Int

    @Binding var anchorDate: Date

    var synchronizer: DateAnchorSynchronizer = DateAnchorSynchronizer()

    var body: some View {
        Picker(String(localized: "Repeat"), selection: $selectedPreset) {
            Text(RecurrencePreset.none.displayName).tag(RecurrencePreset.none)
            Text(RecurrencePreset.weekly.displayName).tag(RecurrencePreset.weekly)
            Text(RecurrencePreset.biweekly.displayName).tag(RecurrencePreset.biweekly)
            Text(RecurrencePreset.monthly.displayName).tag(RecurrencePreset.monthly)
            Divider()
            Text(RecurrencePreset.custom.displayName).tag(RecurrencePreset.custom)
        }
        .pickerStyle(.menu)
        .tint(.secondary)
        .onChange(of: selectedPreset) { oldValue, newValue in
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
        guard selectedPreset != .none else { return }

        switch intervalType {
        case .weekly:
            dayOfWeek = synchronizer.weekday(from: anchorDate)

        case .monthly:
            dayOfMonth = synchronizer.dayOfMonth(from: anchorDate)

        case .yearly:
            break
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
