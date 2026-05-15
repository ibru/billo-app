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

    @Suite("Initialization") @MainActor
    struct Initialization {
        @Test func whenBillInitializedWithTime_thenDueDateStoredAtStartOfDay() {
            let calendar = Calendar.current
            let dueDateWithTime = calendar.date(
                from: DateComponents(year: 2025, month: 1, day: 15, hour: 21, minute: 45)
            ) ?? Date()

            let bill = Bill(
                name: "Test Bill",
                amount: 100,
                dueDate: dueDateWithTime
            )

            #expect(bill.dueDate == calendar.startOfDay(for: dueDateWithTime))
        }
    }

    @Suite("OccurrenceID") @MainActor
    struct OccurrenceIDTests {
        @Test func whenOccurrenceIDsCreatedWithSameNormalizedDate_thenTheyAreEqual() {
            let calendar = Calendar.current
            let midnightDate = calendar.startOfDay(for: Date())

            let id1 = BillOccurrence.OccurrenceID(billID: "test", dueDate: midnightDate)
            let id2 = BillOccurrence.OccurrenceID(billID: "test", dueDate: midnightDate)

            #expect(id1 == id2)
        }

        @Test func whenBillInitNormalizesDate_thenOccurrenceIDsMatchAcrossTimeComponents() {
            let calendar = Calendar.current
            let afternoonDate = calendar.date(
                from: DateComponents(year: 2025, month: 6, day: 15, hour: 14, minute: 30)
            )!

            // Bill.init normalizes to start-of-day, so both paths produce the same dueDate
            let bill = Bill(name: "Test", amount: 100, dueDate: afternoonDate)
            let id1 = BillOccurrence.OccurrenceID(billID: "test", dueDate: bill.dueDate)
            let id2 = BillOccurrence.OccurrenceID(billID: "test", dueDate: bill.dueDate)

            #expect(id1 == id2)
        }
    }

    @Suite("Occurrence Key") @MainActor
    struct OccurrenceKeyTests {
        @Test func whenBillAndSnapshotKeyTheSameDate_thenTheyAgree() throws {
            // The two methods should produce the same key for the same date —
            // both delegate to `OccurrenceKey.make(stableID:date:)`.
            let (bill, _, _, _) = try makeSUT()
            var utc = Calendar(identifier: .gregorian)
            utc.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            let date = try #require(
                utc.date(from: DateComponents(year: 2025, month: 1, day: 1, hour: 12))
            )

            let billKey = bill.occurrenceKey(for: date)
            let snapshotKey = BillSnapshot(bill: bill).occurrenceKey(for: date)

            #expect(billKey == snapshotKey)
        }

        @Test func whenTwoDatesShareUTCDay_thenBillKeysAgree() throws {
            // Locks in the UTC-day identity contract: two `Date` instants that
            // fall on the same UTC day (even if many hours apart) produce the
            // same key. This is what makes the key stable across CloudKit-
            // synced devices in different timezones.
            let (bill, _, _, _) = try makeSUT()
            var utc = Calendar(identifier: .gregorian)
            utc.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            let earlyUTC = try #require(
                utc.date(from: DateComponents(year: 2025, month: 1, day: 15, hour: 2))
            )
            let lateUTC = try #require(
                utc.date(from: DateComponents(year: 2025, month: 1, day: 15, hour: 23))
            )

            #expect(bill.occurrenceKey(for: earlyUTC) == bill.occurrenceKey(for: lateUTC))
        }

        @Test func whenLocalMidnightIsEastOfUTC_thenBillKeyTrailsLocalCalendarDay() throws {
            // Mirrors `IncomeOccurrenceTests.whenLocalMidnightIsEastOfUTC...`:
            // documents the timezone-drift contract on the bill side as well.
            let (bill, _, _, _) = try makeSUT()
            var prague = Calendar(identifier: .gregorian)
            prague.timeZone = try #require(TimeZone(identifier: "Europe/Prague"))
            let pragueMidnight = try #require(
                prague.date(from: DateComponents(year: 2025, month: 1, day: 15, hour: 0))
            )

            #expect(bill.occurrenceKey(for: pragueMidnight).hasSuffix(":2025-01-14"))
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
