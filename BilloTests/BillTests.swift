//  Created by Jiri Urbasek on 11/26/25.

import Testing
import SwiftData
import Foundation
@testable import Billo

@Suite("Bill")
struct BillTests {

    @Suite("status") @MainActor
    struct Status {
        @Test func whenBillIsPaid_thenStatusIsPaid() throws {
            let (bill, calendar, referenceDate, modelContext) = try makeSUT()
            _ = makePaymentEntry(
                amount: bill.amount,
                datePaid: referenceDate,
                occurrenceDate: bill.dueDate,
                bill: bill,
                calendar: calendar,
                in: modelContext
            )

            let status = bill.status(relativeTo: referenceDate, calendar: calendar)

            #expect(status == .paid)
        }

        @Test func whenBillIsDueToday_thenStatusIsDueToday() throws {
            let (bill, calendar, referenceDate, _) = try makeSUT(dueDayOffset: 0)

            let status = bill.status(relativeTo: referenceDate, calendar: calendar)

            #expect(status == .dueToday)
        }

        @Test func whenBillIsOverdue_thenStatusIsOverdue() throws {
            let (bill, calendar, referenceDate, _) = try makeSUT(dueDayOffset: -5)

            let status = bill.status(relativeTo: referenceDate, calendar: calendar)

            #expect(status == .overdue)
        }

        @Test func whenBillIsUpcoming_thenStatusIsUpcoming() throws {
            let (bill, calendar, referenceDate, _) = try makeSUT(dueDayOffset: 5)

            let status = bill.status(relativeTo: referenceDate, calendar: calendar)

            #expect(status == .upcoming)
        }
    }

    @Suite("hasPayment") @MainActor
    struct HasPayment {
        @Test func whenPaymentExistsForOccurrence_thenReturnsTrue() throws {
            let (bill, calendar, referenceDate, modelContext) = try makeSUT()
            _ = makePaymentEntry(
                amount: bill.amount,
                datePaid: referenceDate,
                occurrenceDate: bill.dueDate,
                bill: bill,
                calendar: calendar,
                in: modelContext
            )

            let hasPayment = bill.hasPayment(for: bill.dueDate, calendar: calendar)

            #expect(hasPayment == true)
        }

        @Test func whenNoPaymentExistsForOccurrence_thenReturnsFalse() throws {
            let (bill, calendar, _, _) = try makeSUT()

            let hasPayment = bill.hasPayment(for: bill.dueDate, calendar: calendar)

            #expect(hasPayment == false)
        }

        @Test func whenPaymentExistsForDifferentOccurrence_thenReturnsFalse() throws {
            let (bill, calendar, referenceDate, modelContext) = try makeSUT()
            let differentDate = calendar.date(byAdding: .day, value: 30, to: bill.dueDate)!
            _ = makePaymentEntry(
                amount: bill.amount,
                datePaid: referenceDate,
                occurrenceDate: differentDate,
                bill: bill,
                calendar: calendar,
                in: modelContext
            )

            let hasPayment = bill.hasPayment(for: bill.dueDate, calendar: calendar)

            #expect(hasPayment == false)
        }
    }

    @Suite("generateOccurrences") @MainActor
    struct GenerateOccurrences {
        @Test func whenBillHasNoRecurrence_thenReturnsOnlyOriginalDueDate() throws {
            let (bill, calendar, referenceDate, _) = try makeSUT()
            let endDate = calendar.date(byAdding: .month, value: 3, to: referenceDate)!

            let occurrences = bill.generateOccurrences(
                from: bill.dueDate,
                until: endDate,
                calendar: calendar
            )

            #expect(occurrences.count == 1)
            #expect(occurrences[0] == bill.dueDate)
        }

        @Test func whenBillHasWeeklyRecurrence_thenGeneratesMultipleOccurrences() throws {
            let (bill, calendar, referenceDate, _) = try makeSUTWithRecurrence(
                pattern: .weekly,
                frequency: 1
            )
            let endDate = calendar.date(byAdding: .month, value: 1, to: referenceDate)!

            let occurrences = bill.generateOccurrences(
                from: bill.dueDate,
                until: endDate,
                calendar: calendar
            )

            #expect(occurrences.count >= 4)
        }
    }

    @Suite("Default Currency Code") @MainActor
    struct DefaultCurrencyCode {
        @Test func whenBillCreatedWithoutCurrency_thenUsesLocaleCurrency() throws {
            let expectedCurrency = Locale.current.currency?.identifier ?? "USD"

            let bill = Bill(
                name: "Test Bill",
                amount: 100,
                dueDate: Date()
            )

            #expect(bill.currencyCode == expectedCurrency)
        }

        @Test func whenBillCreatedWithExplicitCurrency_thenUsesProvidedCurrency() throws {
            let bill = Bill(
                name: "Test Bill",
                amount: 100,
                currencyCode: "EUR",
                dueDate: Date()
            )

            #expect(bill.currencyCode == "EUR")
        }
    }

    @Suite("Occurrence Key") @MainActor
    struct OccurrenceKey {
        @Test func whenOccurrenceKeyGeneratedAcrossTimeZones_thenUsesUTCDateOnly() throws {
            let (bill, _, _, _) = try makeSUT()
            var utcCalendar = Calendar(identifier: .gregorian)
            utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            var tokyoCalendar = Calendar(identifier: .gregorian)
            tokyoCalendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
            var laCalendar = Calendar(identifier: .gregorian)
            laCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt

            let occurrenceDate = utcCalendar.date(
                from: DateComponents(year: 2025, month: 1, day: 1, hour: 23, minute: 30)
            ) ?? Date()

            let keyUTC = bill.occurrenceKey(for: occurrenceDate, calendar: utcCalendar)
            let keyTokyo = bill.occurrenceKey(for: occurrenceDate, calendar: tokyoCalendar)
            let keyLA = bill.occurrenceKey(for: occurrenceDate, calendar: laCalendar)
            let snapshotKey = BillSnapshot(bill: bill).occurrenceKey(for: occurrenceDate, calendar: tokyoCalendar)

            #expect(Set([keyUTC, keyTokyo, keyLA, snapshotKey]).count == 1)
        }
    }

    @Suite("IssuedOccurrence") @MainActor
    struct IssuedOccurrenceTests {
        @Test func whenIssuedOccurrenceHasNoPayments_thenIsPaidIsFalse() throws {
            let (bill, calendar, _, modelContext) = try makeSUT()
            let issued = makeIssuedOccurrence(for: bill, dueDate: bill.dueDate, calendar: calendar, in: modelContext)

            #expect(issued.isPaid == false)
        }

        @Test func whenIssuedOccurrenceIsFullyPaid_thenIsPaidIsTrue() throws {
            let (bill, calendar, referenceDate, modelContext) = try makeSUT()
            let issued = makeIssuedOccurrence(for: bill, dueDate: bill.dueDate, calendar: calendar, in: modelContext)

            _ = makePaymentEntry(
                amount: bill.amount,
                datePaid: referenceDate,
                occurrenceDate: bill.dueDate,
                bill: bill,
                calendar: calendar,
                in: modelContext
            )
            try modelContext.save()

            #expect(issued.isPaid == true)
        }
    }
}

// MARK: - makeSUT & Factories

private func makeSUT(
    dueDayOffset: Int = 0
) throws -> (Bill, Calendar, Date, ModelContext) {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Bill.self, PaymentEntry.self, IssuedOccurrence.self, configurations: config)
    let modelContext = ModelContext(container)

    let calendar = Calendar.current
    let referenceDate = makeDate(year: 2025, month: 1, day: 15)
    let dueDate = calendar.date(byAdding: .day, value: dueDayOffset, to: referenceDate)!

    let bill = Bill(
        name: "Test Bill",
        amount: 100,
        dueDate: dueDate
    )
    modelContext.insert(bill)

    try modelContext.save()

    return (bill, calendar, referenceDate, modelContext)
}

private func makeSUTWithRecurrence(
    pattern: RepeatIntervalType,
    frequency: Int = 1
) throws -> (Bill, Calendar, Date, ModelContext) {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Bill.self,
        PaymentEntry.self,
        IssuedOccurrence.self,
        RecurrenceRule.self,
        configurations: config
    )
    let modelContext = ModelContext(container)

    let calendar = Calendar.current
    let referenceDate = makeDate(year: 2025, month: 1, day: 15)

    let recurrenceRule = RecurrenceRule(pattern: pattern, frequency: frequency)
    let bill = Bill(
        name: "Recurring Bill",
        amount: 100,
        dueDate: referenceDate,
        recurrenceRule: recurrenceRule
    )
    modelContext.insert(bill)

    try modelContext.save()

    return (bill, calendar, referenceDate, modelContext)
}

private func makeDate(year: Int = 2025, month: Int = 1, day: Int) -> Date {
    let calendar = Calendar.current
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return calendar.date(from: components)!
}
