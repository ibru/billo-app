//  Created by Jiri Urbasek on 1/20/26.

import SwiftUI

struct RecurrencePresetPicker: View {
    @Binding var selectedPreset: RecurrencePreset

    @Binding var intervalType: RepeatIntervalType
    @Binding var frequency: Int
    @Binding var dayOfWeek: Weekday
    @Binding var dayOfMonth: Int

    let anchorDate: Date

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

        let calendar = Calendar.current
        switch intervalType {
        case .weekly:
            let weekday = calendar.component(.weekday, from: anchorDate)
            dayOfWeek = Weekday.fromCalendarWeekday(weekday) ?? .monday

        case .monthly:
            dayOfMonth = calendar.component(.day, from: anchorDate)

        case .yearly:
            break
        }
    }
}
