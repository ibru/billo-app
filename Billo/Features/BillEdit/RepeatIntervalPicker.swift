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
                Text("Weekly").tag(RepeatIntervalType.weekly)
                Text("Monthly").tag(RepeatIntervalType.monthly)
                Text("Yearly").tag(RepeatIntervalType.yearly)
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

                Text(frequency == 1 ? "week on" : "weeks on")

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

                Text(frequency == 1 ? "month on the" : "months on the")

                Picker("Day of Month", selection: $dayOfMonth) {
                    ForEach(1...31, id: \.self) { day in
                        Text("\(day)\(daySuffix(day))").tag(day)
                    }
                }
                .labelsHidden()
            }

        case .yearly:
            EmptyView()
        }
    }

    private func daySuffix(_ day: Int) -> String {
        switch day {
        case 1, 21, 31: return "st"
        case 2, 22: return "nd"
        case 3, 23: return "rd"
        default: return "th"
        }
    }
}
