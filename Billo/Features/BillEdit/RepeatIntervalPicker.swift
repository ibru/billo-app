//  Created by Jiri Urbasek on 11/26/25.

import SwiftUI

struct RepeatIntervalPicker: View {
    @Binding var selectedIntervalType: RepeatIntervalType
    @Binding var frequency: Int
    @Binding var dayOfWeek: Weekday
    @Binding var dayOfMonth: Int
    let dueDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Repeat Type", selection: $selectedIntervalType) {
                Text(RepeatIntervalType.weekly.displayName).tag(RepeatIntervalType.weekly)
                Text(RepeatIntervalType.monthly.displayName).tag(RepeatIntervalType.monthly)
                Text(RepeatIntervalType.yearly.displayName).tag(RepeatIntervalType.yearly)
            }
            .pickerStyle(.segmented)

            configurationView
        }
    }

    @ViewBuilder
    private var configurationView: some View {
        switch selectedIntervalType {
        case .weekly:
            HStack {
                Text("Every")

                Picker("Frequency", selection: $frequency) {
                    ForEach(1...12, id: \.self) { num in
                        Text("\(num)").tag(num)
                    }
                }
                .labelsHidden()
                .frame(width: 60)

                Text(frequency == 1
                    ? String(
                        localized: "week on",
                        comment: "Repeat interval picker: fragment used in 'Every [N] week(s) on [weekday]'"
                    )
                    : String(
                        localized: "weeks on",
                        comment: "Repeat interval picker: fragment used in 'Every [N] week(s) on [weekday]'"
                    )
                )

                Picker("Day of Week", selection: $dayOfWeek) {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        Text(day.displayName).tag(day)
                    }
                }
                .labelsHidden()
            }

        case .monthly:
            HStack {
                Text("Every")

                Picker("Frequency", selection: $frequency) {
                    ForEach(1...12, id: \.self) { num in
                        Text("\(num)").tag(num)
                    }
                }
                .labelsHidden()
                .frame(width: 60)

                Text(frequency == 1
                    ? String(
                        localized: "month on the",
                        comment: "Repeat interval picker: fragment used in 'Every [N] month(s) on the [ordinal day]'"
                    )
                    : String(
                        localized: "months on the",
                        comment: "Repeat interval picker: fragment used in 'Every [N] month(s) on the [ordinal day]'"
                    )
                )

                Picker("Day of Month", selection: $dayOfMonth) {
                    ForEach(1...31, id: \.self) { day in
                        Text(day.localizedOrdinal()).tag(day)
                    }
                }
                .labelsHidden()
            }

        case .yearly:
            EmptyView()
        }
    }
}
