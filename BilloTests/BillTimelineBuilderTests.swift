//  Created by Jiri Urbasek on 04/03/26.

import Testing
import Foundation
@testable import Billo

@Suite("BillTimelineBuilder")
struct BillTimelineBuilderTests {

    @Suite("sorting")
    struct Sorting {
        @Test func whenMixedPaidAndUpcoming_thenSortsChronologically() {
            let (calendar, _) = makeCalendarAndDate()
            let jan = makeDate(month: 1, day: 15, calendar: calendar)
            let feb = makeDate(month: 2, day: 15, calendar: calendar)
            let mar = makeDate(month: 3, day: 15, calendar: calendar)
            let apr = makeDate(month: 4, day: 15, calendar: calendar)

            let payments = [
                makePaymentInput(occurrenceDate: feb, paidDate: feb),
                makePaymentInput(occurrenceDate: jan, paidDate: jan),
            ]

            let result = BillTimelineBuilder.build(
                paymentInputs: payments,
                futureDates: [apr, mar],
                calendar: calendar
            )

            let sortDates = result.map(\.sortDate)
            #expect(sortDates == [jan, feb, mar, apr])
        }

        @Test func whenAllPaid_thenSortsByOccurrenceDate() {
            let (calendar, _) = makeCalendarAndDate()
            let jan = makeDate(month: 1, day: 10, calendar: calendar)
            let feb = makeDate(month: 2, day: 10, calendar: calendar)
            let mar = makeDate(month: 3, day: 10, calendar: calendar)

            // Payments added in reverse order
            let payments = [
                makePaymentInput(occurrenceDate: mar, paidDate: mar),
                makePaymentInput(occurrenceDate: jan, paidDate: jan),
                makePaymentInput(occurrenceDate: feb, paidDate: feb),
            ]

            let result = BillTimelineBuilder.build(
                paymentInputs: payments,
                futureDates: [],
                calendar: calendar
            )

            let sortDates = result.map(\.sortDate)
            #expect(sortDates == [jan, feb, mar])
        }
    }

    @Suite("deduplication")
    struct Deduplication {
        @Test func whenFutureDateAlreadyPaid_thenExcludesFromUpcoming() {
            let (calendar, _) = makeCalendarAndDate()
            let apr = makeDate(month: 4, day: 5, calendar: calendar)
            let may = makeDate(month: 5, day: 5, calendar: calendar)

            let payments = [
                makePaymentInput(occurrenceDate: apr, paidDate: apr),
            ]

            let result = BillTimelineBuilder.build(
                paymentInputs: payments,
                futureDates: [apr, may],
                calendar: calendar
            )

            #expect(result.count == 2)
            #expect(result[0].isPaid == true)
            #expect(result[0].sortDate == apr)
            #expect(result[1].isPaid == false)
            #expect(result[1].sortDate == may)
        }

        @Test func whenNoOverlap_thenIncludesAll() {
            let (calendar, _) = makeCalendarAndDate()
            let jan = makeDate(month: 1, day: 15, calendar: calendar)
            let may = makeDate(month: 5, day: 15, calendar: calendar)
            let jun = makeDate(month: 6, day: 15, calendar: calendar)

            let payments = [
                makePaymentInput(occurrenceDate: jan, paidDate: jan),
            ]

            let result = BillTimelineBuilder.build(
                paymentInputs: payments,
                futureDates: [may, jun],
                calendar: calendar
            )

            #expect(result.count == 3)
            #expect(result.filter(\.isPaid).count == 1)
        }
    }

    @Suite("partial payments")
    struct PartialPayments {
        @Test func whenOccurrencePartiallyPaid_thenStillShowsAsUpcoming() {
            let (calendar, _) = makeCalendarAndDate()
            let apr = makeDate(month: 4, day: 5, calendar: calendar)

            // Paid $50 of $200 — should NOT suppress the upcoming entry
            let payments = [
                makePaymentInput(occurrenceDate: apr, paidDate: apr, amount: 50, expectedAmount: 200),
            ]

            let result = BillTimelineBuilder.build(
                paymentInputs: payments,
                futureDates: [apr],
                calendar: calendar
            )

            #expect(result.count == 2)
            #expect(result[0].isPaid == true)
            #expect(result[1].isPaid == false)
        }

        @Test func whenOccurrenceFullyPaid_thenSuppressesUpcoming() {
            let (calendar, _) = makeCalendarAndDate()
            let apr = makeDate(month: 4, day: 5, calendar: calendar)

            let payments = [
                makePaymentInput(occurrenceDate: apr, paidDate: apr, amount: 200, expectedAmount: 200),
            ]

            let result = BillTimelineBuilder.build(
                paymentInputs: payments,
                futureDates: [apr],
                calendar: calendar
            )

            // Only the paid entry, upcoming suppressed
            #expect(result.count == 1)
            #expect(result[0].isPaid == true)
        }

        @Test func whenMultiplePartialsReachFullAmount_thenSuppressesUpcoming() {
            let (calendar, _) = makeCalendarAndDate()
            let apr = makeDate(month: 4, day: 5, calendar: calendar)

            let payments = [
                makePaymentInput(occurrenceDate: apr, paidDate: apr, amount: 100, expectedAmount: 200),
                makePaymentInput(occurrenceDate: apr, paidDate: apr, amount: 100, expectedAmount: 200),
            ]

            let result = BillTimelineBuilder.build(
                paymentInputs: payments,
                futureDates: [apr],
                calendar: calendar
            )

            // Two paid entries, upcoming suppressed since total ($200) >= expected ($200)
            #expect(result.count == 2)
            #expect(result.map(\.isPaid) == [true, true])
        }
    }

    @Suite("entry types")
    struct EntryTypes {
        @Test func whenOnlyFutureDates_thenAllUpcoming() {
            let (calendar, _) = makeCalendarAndDate()
            let may = makeDate(month: 5, day: 1, calendar: calendar)
            let jun = makeDate(month: 6, day: 1, calendar: calendar)

            let result = BillTimelineBuilder.build(
                paymentInputs: [],
                futureDates: [may, jun],
                calendar: calendar
            )

            #expect(result.count == 2)
            #expect(result.allSatisfy { !$0.isPaid })
        }

        @Test func whenOnlyPayments_thenAllPaid() {
            let (calendar, _) = makeCalendarAndDate()
            let jan = makeDate(month: 1, day: 1, calendar: calendar)
            let feb = makeDate(month: 2, day: 1, calendar: calendar)

            let payments = [
                makePaymentInput(occurrenceDate: jan, paidDate: jan),
                makePaymentInput(occurrenceDate: feb, paidDate: feb),
            ]

            let result = BillTimelineBuilder.build(
                paymentInputs: payments,
                futureDates: [],
                calendar: calendar
            )

            #expect(result.count == 2)
            #expect(result.map(\.isPaid) == [true, true])
        }

        @Test func whenEmpty_thenReturnsEmpty() {
            let (calendar, _) = makeCalendarAndDate()

            let result = BillTimelineBuilder.build(
                paymentInputs: [],
                futureDates: [],
                calendar: calendar
            )

            #expect(result.isEmpty)
        }
    }

    @Suite("paid entry data")
    struct PaidEntryData {
        @Test func whenPaymentHasConfirmation_thenEntryPreservesIt() {
            let (calendar, _) = makeCalendarAndDate()
            let date = makeDate(month: 3, day: 1, calendar: calendar)

            let payments = [
                makePaymentInput(
                    occurrenceDate: date,
                    paidDate: date,
                    amount: 99.50,
                    currencyCode: "EUR",
                    confirmationNumber: "REF-123"
                ),
            ]

            let result = BillTimelineBuilder.build(
                paymentInputs: payments,
                futureDates: [],
                calendar: calendar
            )

            guard case .paid(let entry) = result.first else {
                Issue.record("Expected paid entry")
                return
            }
            #expect(entry.amount == 99.50)
            #expect(entry.currencyCode == "EUR")
            #expect(entry.confirmationNumber == "REF-123")
        }

        @Test func whenPaidEarlyForFutureOccurrence_thenUsesOccurrenceDateForSort() {
            let (calendar, _) = makeCalendarAndDate()
            let paidDate = makeDate(month: 3, day: 28, calendar: calendar)
            let occurrenceDate = makeDate(month: 4, day: 5, calendar: calendar)
            let futureDate = makeDate(month: 5, day: 5, calendar: calendar)

            let payments = [
                makePaymentInput(occurrenceDate: occurrenceDate, paidDate: paidDate),
            ]

            let result = BillTimelineBuilder.build(
                paymentInputs: payments,
                futureDates: [futureDate],
                calendar: calendar
            )

            #expect(result.count == 2)
            #expect(result[0].sortDate == calendar.startOfDay(for: occurrenceDate))
            #expect(result[1].sortDate == calendar.startOfDay(for: futureDate))
        }
    }
}

// MARK: - makeSUT & Factories

private func makeCalendarAndDate() -> (Calendar, Date) {
    let calendar = Calendar.current
    let date = calendar.date(from: DateComponents(year: 2026, month: 4, day: 3))!
    return (calendar, date)
}

private func makeDate(
    year: Int = 2026,
    month: Int,
    day: Int,
    calendar: Calendar = .current
) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day))!
}

private func makePaymentInput(
    occurrenceDate: Date,
    paidDate: Date,
    amount: Decimal = 100,
    expectedAmount: Decimal = 100,
    currencyCode: String = "USD",
    confirmationNumber: String? = nil
) -> BillTimelineBuilder.PaymentInput {
    BillTimelineBuilder.PaymentInput(
        occurrenceDate: occurrenceDate,
        paidDate: paidDate,
        amount: amount,
        expectedAmount: expectedAmount,
        currencyCode: currencyCode,
        confirmationNumber: confirmationNumber
    )
}
