//  Created by Jiri Urbasek on 02/11/26.

import Testing
import Foundation
@testable import Billo

@Suite("RecurrencePresetPicker") @MainActor
struct RecurrencePresetPickerTests {
    @Suite("anchoredRepeatFieldValues") @MainActor
    struct AnchoredRepeatFieldValues {
        @Test func whenPresetIsMonthly_andAnchorDateIs30th_thenReturnsDayOfMonth30() {
            let synchronizer = makeSynchronizer()
            let anchorDate = makeDate(year: 2026, month: 1, day: 30)

            let result = RecurrencePresetPicker.anchoredRepeatFieldValues(
                selectedPreset: .monthly,
                intervalType: .monthly,
                anchorDate: anchorDate,
                synchronizer: synchronizer
            )

            #expect(result.dayOfWeek == nil)
            #expect(result.dayOfMonth == 30)
        }

        @Test func whenPresetIsWeekly_andAnchorDateIsTuesday_thenReturnsTuesday() {
            let synchronizer = makeSynchronizer()
            let anchorDate = makeDate(year: 2026, month: 2, day: 10) // Tuesday

            let result = RecurrencePresetPicker.anchoredRepeatFieldValues(
                selectedPreset: .weekly,
                intervalType: .weekly,
                anchorDate: anchorDate,
                synchronizer: synchronizer
            )

            #expect(result.dayOfWeek == .tuesday)
            #expect(result.dayOfMonth == nil)
        }

        @Test func whenPresetIsNone_thenReturnsNilValues() {
            let synchronizer = makeSynchronizer()
            let anchorDate = makeDate(year: 2026, month: 2, day: 10)

            let result = RecurrencePresetPicker.anchoredRepeatFieldValues(
                selectedPreset: .none,
                intervalType: .monthly,
                anchorDate: anchorDate,
                synchronizer: synchronizer
            )

            #expect(result.dayOfWeek == nil)
            #expect(result.dayOfMonth == nil)
        }
    }
}

// MARK: - Test Helpers

@MainActor
private func makeSynchronizer() -> DateAnchorSynchronizer {
    DateAnchorSynchronizer(calendar: makeUTCCalendar())
}

private func makeDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day

    return makeUTCCalendar().date(from: components)!
}

private func makeUTCCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.locale = Locale(identifier: "en_US")
    return calendar
}
