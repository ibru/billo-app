//  Created by Jiri Urbasek on 12/04/25.

import Foundation
import Testing
@testable import Billo

@Suite("BillOccurrence - Countdown") @MainActor
struct BillOccurrenceCountdownTests {

    @Test
    func whenDueToday_thenReturnsZeroDays() {
        let calendar = makeCalendar()
        let referenceDate = makeDate(year: 2025, month: 12, day: 4, calendar: calendar)
        let occurrence = makeOccurrence(dueInDays: 0, from: referenceDate, calendar: calendar)

        let countdown = occurrence.dueCountdown(relativeTo: referenceDate, calendar: calendar)

        #expect(countdown == .days(0))
    }

    @Test
    func whenDueTomorrow_thenReturnsPositiveDays() {
        let calendar = makeCalendar()
        let referenceDate = makeDate(year: 2025, month: 12, day: 4, calendar: calendar)
        let occurrence = makeOccurrence(dueInDays: 1, from: referenceDate, calendar: calendar)

        let countdown = occurrence.dueCountdown(relativeTo: referenceDate, calendar: calendar)

        #expect(countdown == .days(1))
    }

    @Test
    func whenOverdue_thenReturnsNegativeDays() {
        let calendar = makeCalendar()
        let referenceDate = makeDate(year: 2025, month: 12, day: 4, calendar: calendar)
        let occurrence = makeOccurrence(dueInDays: -5, from: referenceDate, calendar: calendar)

        let countdown = occurrence.dueCountdown(relativeTo: referenceDate, calendar: calendar)

        #expect(countdown == .days(-5))
    }

    @Test
    func whenDueInSixtyOneDays_thenUsesMonths() {
        let calendar = makeCalendar()
        let referenceDate = makeDate(year: 2025, month: 12, day: 4, calendar: calendar)
        let occurrence = makeOccurrence(dueInDays: 61, from: referenceDate, calendar: calendar)

        let countdown = occurrence.dueCountdown(relativeTo: referenceDate, calendar: calendar)

        #expect(countdown == .months(2.0))
    }

    @Test
    func whenDueInSeventyFiveDays_thenRoundsMonthsToSingleDecimal() {
        let calendar = makeCalendar()
        let referenceDate = makeDate(year: 2025, month: 12, day: 4, calendar: calendar)
        let occurrence = makeOccurrence(dueInDays: 75, from: referenceDate, calendar: calendar)

        let countdown = occurrence.dueCountdown(relativeTo: referenceDate, calendar: calendar)

        #expect(countdown == .months(2.5))
    }

    @Test
    func whenFormattingMonths_thenRespectsLocaleDecimalSeparator() {
        let calendar = makeCalendar()
        let referenceDate = makeDate(year: 2025, month: 12, day: 4, calendar: calendar)
        let occurrence = makeOccurrence(dueInDays: 75, from: referenceDate, calendar: calendar)
        let frenchLocale = Locale(identifier: "fr_FR")

        let formatted = occurrence
            .dueCountdown(relativeTo: referenceDate, calendar: calendar)
            .formatted(locale: frenchLocale)

        #expect(formatted.value == "2,5")
        #expect(formatted.unit == String(localized: "months", defaultValue: "months", locale: frenchLocale))
    }
}

// MARK: - makeSUT & Factories

@MainActor
private func makeOccurrence(
    dueInDays offset: Int,
    from referenceDate: Date,
    calendar: Calendar
) -> BillOccurrence {
    let dueDate = calendar.date(byAdding: .day, value: offset, to: referenceDate)!
    return BillOccurrence(bill: makeBill(dueDate: dueDate), dueDate: dueDate)
}

@MainActor
private func makeBill(dueDate: Date) -> Bill {
    Bill(
        name: "Electricity",
        amount: 120,
        currencyCode: "USD",
        dueDate: dueDate
    )
}

private func makeCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.timeZone = calendar.timeZone
    return calendar.date(from: components)!
}

// MARK: - Test Factories for Countdown

private extension BillOccurrence.Countdown {
    static func days(_ value: Double) -> Self {
        .init(value: value, unit: .days)
    }

    static func months(_ value: Double) -> Self {
        .init(value: value, unit: .months)
    }
}

// MARK: - SwiftTesting Debug Support

@MainActor
extension BillOccurrence.Countdown: CustomTestStringConvertible, CustomDebugStringConvertible {
    public var debugDescription: String { testDescription }

    public var testDescription: String {
        switch unit {
        case .days:
            let intValue = Int(value)
            return intValue == 0 ? "today" : "\(intValue) days"
        case .months:
            return String(format: "%.1f months", value)
        }
    }
}
