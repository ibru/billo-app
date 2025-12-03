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

    @Suite("digestBody")
    @MainActor
    struct DigestBody {

        @Test
        func whenSingleCurrencyProvided_thenIncludesTotalAmount() {
            #expect(makeSUT().digestBody(
                billCount: 3,
                totalAmount: 450.99,
                currencyCode: "USD",
                lookaheadDays: 5
            ) == "3 bills ($450.99) due in next 5 days")
        }

        @Test
        func whenMixedCurrencies_thenShowsCountOnly() {
            #expect(makeSUT().digestBody(
                billCount: 5,
                totalAmount: nil,
                currencyCode: nil,
                lookaheadDays: 7
            ) == "5 bills due in next 7 days")
        }

        @Test
        func whenOneBill_thenUseSingularForm() {
            #expect(makeSUT().digestBody(
                billCount: 1,
                totalAmount: 50.0,
                currencyCode: "USD",
                lookaheadDays: 3
            ) == "1 bill ($50.00) due in next 3 days")
        }

        @Test
        func whenThreeDayLookahead_thenIncludesCorrectWindow() {
            #expect(makeSUT().digestBody(
                billCount: 2,
                totalAmount: 200,
                currencyCode: "EUR",
                lookaheadDays: 3
            ) == "2 bills (€200.00) due in next 3 days")
        }

        @Test
        func whenSevenDayLookahead_thenIncludesCorrectWindow() {
            #expect(makeSUT().digestBody(
                billCount: 4,
                totalAmount: nil,
                currencyCode: nil,
                lookaheadDays: 7
            ) == "4 bills due in next 7 days")
        }

        // MARK: - Helpers

        private func makeSUT(locale: Locale = Locale(identifier: "en_US")) -> NotificationContentBuilder {
            NotificationContentBuilder(locale: locale)
        }
    }
}
