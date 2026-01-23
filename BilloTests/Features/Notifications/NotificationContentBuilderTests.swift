//  Created by Jiri Urbasek on 12/02/25.

import Testing
import Foundation
@testable import Billo

@Suite("NotificationContentBuilder")
@MainActor
struct NotificationContentBuilderTests {

    @Suite("reminderBody")
    @MainActor
    struct ReminderBody {

        @Test
        func whenOffsetIsZero_thenReturnsDueTodayMessage() {
            #expect(makeSUT().reminderBody(
                amount: 49.99,
                currencyCode: "USD",
                offsetDays: 0
            ) == "$49.99 is due today")
        }

        @Test
        func whenOffsetIsOne_thenReturnsDueTomorrowMessage() {
            #expect(makeSUT().reminderBody(
                amount: 25.50,
                currencyCode: "EUR",
                offsetDays: 1
            ) == "€25.50 is due tomorrow")
        }

        @Test
        func whenOffsetIsThree_thenReturnsDueInDaysMessage() {
            #expect(makeSUT().reminderBody(
                amount: 150.00,
                currencyCode: "USD",
                offsetDays: 3
            ) == "$150.00 is due in 3 days")
        }

        @Test
        func whenOffsetIsSeven_thenReturnsDueInDaysMessage() {
            #expect(makeSUT().reminderBody(
                amount: 99.99,
                currencyCode: "GBP",
                offsetDays: 7
            ) == "£99.99 is due in 7 days")
        }

        @Test
        func whenDifferentCurrencies_thenFormatsCorrectly() {
            #expect(makeSUT().reminderBody(
                amount: 100,
                currencyCode: "USD",
                offsetDays: 0
            ) == "$100.00 is due today")

            #expect(makeSUT().reminderBody(
                amount: 100,
                currencyCode: "EUR",
                offsetDays: 0
            ) == "€100.00 is due today")
        }

        // MARK: - Helpers

        private func makeSUT(locale: Locale = Locale(identifier: "en_US")) -> NotificationContentBuilder {
            NotificationContentBuilder(locale: locale)
        }
    }

    @Suite("digestTitle")
    @MainActor
    struct DigestTitle {

        @Test
        func whenOneBill_thenUsesSingularForm() {
            #expect(makeSUT().digestTitle(
                upcomingCount: 1,
                lookaheadDays: 3,
                overdueCount: 0
            ) == "1 bill due in next 3 days")
        }

        @Test
        func whenLookaheadIsOneDay_thenUsesSingularDay() {
            #expect(makeSUT().digestTitle(
                upcomingCount: 2,
                lookaheadDays: 1,
                overdueCount: 0
            ) == "2 bills due in next 1 day")
        }

        @Test
        func whenMultipleBills_thenUsesPluralForm() {
            #expect(makeSUT().digestTitle(
                upcomingCount: 5,
                lookaheadDays: 7,
                overdueCount: 0
            ) == "5 bills due in next 7 days")
        }

        @Test
        func whenOnlyOverdue_thenUsesOverdueTitle() {
            #expect(makeSUT().digestTitle(
                upcomingCount: 0,
                lookaheadDays: 5,
                overdueCount: 2
            ) == "2 bills are overdue")
        }

        // MARK: - Helpers

        private func makeSUT(
            locale: Locale = Locale(identifier: "en_US"),
            timeZone: TimeZone = TimeZone(identifier: "UTC")!
        ) -> NotificationContentBuilder {
            NotificationContentBuilder(locale: locale, timeZone: timeZone)
        }
    }

    @Suite("digestBody")
    @MainActor
    struct DigestBody {

        @Test
        func whenItemsAreEmpty_thenReturnsEmptyString() {
            #expect(makeSUT().digestBody(upcomingItems: [], overdueItems: []) == "")
        }

        @Test
        func whenItemsProvided_thenListsNameAmountAndDueDate() {
            let rent = makeItem(name: "Rent", amount: 10, currencyCode: "USD", dueDate: makeDate(2025, 12, 2))
            let gym = makeItem(name: "Gym", amount: 20, currencyCode: "EUR", dueDate: makeDate(2025, 12, 3))

            #expect(makeSUT().digestBody(upcomingItems: [rent, gym], overdueItems: []) == """
            Rent — $10.00 — Dec 2
            Gym — €20.00 — Dec 3
            """)
        }

        @Test
        func whenMoreThanFiveItems_thenListsFirstFiveAndTruncates() {
            let items = (1...7).map { idx in
                makeItem(
                    name: "Bill \(idx)",
                    amount: Decimal(idx),
                    currencyCode: "USD",
                    dueDate: makeDate(2025, 12, idx)
                )
            }

            #expect(makeSUT().digestBody(upcomingItems: items, overdueItems: [], maxLines: 5) == """
            Bill 1 — $1.00 — Dec 1
            Bill 2 — $2.00 — Dec 2
            Bill 3 — $3.00 — Dec 3
            Bill 4 — $4.00 — Dec 4
            Bill 5 — $5.00 — Dec 5
            …and 2 more
            """)
        }

        @Test
        func whenUpcomingAndOverdue_thenAppendsOverdueSummary() {
            let upcoming = [
                makeItem(name: "Rent", amount: 10, currencyCode: "USD", dueDate: makeDate(2025, 12, 2)),
                makeItem(name: "Gym", amount: 20, currencyCode: "USD", dueDate: makeDate(2025, 12, 3))
            ]
            let overdue = [
                makeItem(name: "Water", amount: 5, currencyCode: "USD", dueDate: makeDate(2025, 11, 20)),
                makeItem(name: "Phone", amount: 7, currencyCode: "USD", dueDate: makeDate(2025, 11, 10))
            ]

            #expect(makeSUT().digestBody(upcomingItems: upcoming, overdueItems: overdue) == """
            Rent — $10.00 — Dec 2
            Gym — $20.00 — Dec 3
            Water — $5.00 — Nov 20
            plus 1 more bill is overdue
            """)
        }

        @Test
        func whenOnlyOverdue_thenListsUpToThreeAndSummarizes() {
            let overdue = (1...4).map { idx in
                makeItem(
                    name: "Overdue \(idx)",
                    amount: Decimal(idx),
                    currencyCode: "USD",
                    dueDate: makeDate(2025, 11, 10 + idx)
                )
            }

            #expect(makeSUT().digestBody(upcomingItems: [], overdueItems: overdue) == """
            Overdue 1 — $1.00 — Nov 11
            Overdue 2 — $2.00 — Nov 12
            Overdue 3 — $3.00 — Nov 13
            plus 1 more bill is overdue
            """)
        }

        // MARK: - Helpers

        private func makeSUT(
            locale: Locale = Locale(identifier: "en_US"),
            timeZone: TimeZone = TimeZone(identifier: "UTC")!
        ) -> NotificationContentBuilder {
            NotificationContentBuilder(locale: locale, timeZone: timeZone)
        }

        private func makeItem(
            name: String,
            amount: Decimal,
            currencyCode: String,
            dueDate: Date
        ) -> NotificationContentBuilder.NotificationDigestItem {
            NotificationContentBuilder.NotificationDigestItem(
                name: name,
                amount: amount,
                currencyCode: currencyCode,
                dueDate: dueDate
            )
        }

        private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            components.hour = 0
            components.minute = 0

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            calendar.locale = Locale(identifier: "en_US")

            return calendar.date(from: components)!
        }
    }
}
