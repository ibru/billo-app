//  Created by Jiri Urbasek on 04/03/26.

import Testing
import SwiftData
import Foundation
@testable import Billo

@Suite("BillDetailView")
struct BillDetailTests {

    @Suite("dueBadgeText")
    struct DueBadgeText {
        @Test func whenBillIsOverdue_thenShowsOverdueByDays() {
            let (calendar, referenceDate) = makeCalendarAndDate()
            let dueDate = calendar.date(byAdding: .day, value: -5, to: referenceDate)!

            let text = BillDetailView.dueBadgeText(dueDate: dueDate, relativeTo: referenceDate, calendar: calendar)

            #expect(text == "Overdue by 5 days")
        }

        @Test func whenBillIsDueToday_thenShowsDueToday() {
            let (calendar, referenceDate) = makeCalendarAndDate()

            let text = BillDetailView.dueBadgeText(dueDate: referenceDate, relativeTo: referenceDate, calendar: calendar)

            #expect(text == "Due Today")
        }

        @Test func whenBillIsDueInFuture_thenShowsDueInDays() {
            let (calendar, referenceDate) = makeCalendarAndDate()
            let dueDate = calendar.date(byAdding: .day, value: 17, to: referenceDate)!

            let text = BillDetailView.dueBadgeText(dueDate: dueDate, relativeTo: referenceDate, calendar: calendar)

            #expect(text == "Due in 17 days")
        }

        @Test func whenBillIsOverdueByOneDay_thenShowsSingularDay() {
            let (calendar, referenceDate) = makeCalendarAndDate()
            let dueDate = calendar.date(byAdding: .day, value: -1, to: referenceDate)!

            let text = BillDetailView.dueBadgeText(dueDate: dueDate, relativeTo: referenceDate, calendar: calendar)

            #expect(text == "Overdue by 1 day")
        }

        @Test func whenBillIsDueTomorrow_thenShowsDueTomorrow() {
            let (calendar, referenceDate) = makeCalendarAndDate()
            let dueDate = calendar.date(byAdding: .day, value: 1, to: referenceDate)!

            let text = BillDetailView.dueBadgeText(dueDate: dueDate, relativeTo: referenceDate, calendar: calendar)

            #expect(text == "Due Tomorrow")
        }
    }

    @Suite("formattedAsCurrency")
    struct FormattedAsCurrency {
        @Test func whenFormattingUSD_thenIncludesDollarSign() {
            let amount: Decimal = 100.50
            let formatted = amount.formattedAsCurrency(code: "USD", locale: Locale(identifier: "en_US"))

            #expect(formatted.contains("100"))
            #expect(formatted.contains("50"))
        }

        @Test func whenFormattingZero_thenFormatsCorrectly() {
            let amount: Decimal = 0
            let formatted = amount.formattedAsCurrency(code: "USD", locale: Locale(identifier: "en_US"))

            #expect(formatted.contains("0"))
        }
    }
}

// MARK: - makeSUT & Factories

private func makeCalendarAndDate(
    year: Int = 2026,
    month: Int = 4,
    day: Int = 3
) -> (Calendar, Date) {
    let calendar = Calendar.current
    let date = calendar.date(from: DateComponents(year: year, month: month, day: day))!
    return (calendar, date)
}
