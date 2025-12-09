//  Created by Jiri Urbasek on 11/28/25.

import Testing
import SwiftData
import Foundation
@testable import Billo

@Suite("Bill - Occurrence Generation") @MainActor
struct BillOccurrenceGenerationTests {

    @Test func whenWeeklyBill_thenPreservesWeekday() throws {
        let (bill, _) = try makeSUT(
            dueDate: makeDate(month: 9, day: 3),  // Wednesday in 2025
            pattern: .weekly
        )

        let unpaid = bill.unpaidOccurrences(
            aroundDate: makeDate(month: 10, day: 1),
            calendar: .current
        )

        // All occurrences should match the original weekday
        let expectedWeekday = Calendar.current.component(.weekday, from: bill.dueDate)
        for occurrence in unpaid {
            let weekday = Calendar.current.component(.weekday, from: occurrence)
            #expect(weekday == expectedWeekday, "Expected weekday \(expectedWeekday), got \(weekday)")
        }
    }

    @Test func whenWeeklyBillOverdueOneYear_thenIncludesAllInWindow() throws {
        let (bill, _) = try makeSUT(
            dueDate: makeDate(year: 2024, month: 9, day: 1),
            pattern: .weekly
        )

        let unpaid = bill.unpaidOccurrences(
            aroundDate: makeDate(year: 2025, month: 9, day: 15),  // 1 year later
            calendar: .current
        )

        // 18 month lookback = ~52 weekly occurrences per year
        #expect(unpaid.count >= 52, "Expected at least 52 weekly occurrences (18mo window)")
    }

    @Test func whenWeeklyBillOverdue18Months_thenIncludesAllInWindow() throws {
        let (bill, _) = try makeSUT(
            dueDate: makeDate(year: 2024, month: 1, day: 1),
            pattern: .weekly
        )

        let unpaid = bill.unpaidOccurrences(
            aroundDate: makeDate(year: 2025, month: 7, day: 1),  // 18 months later
            calendar: .current
        )

        // 18 month lookback = ~78 occurrences
        #expect(unpaid.count >= 78, "Expected at least 78 weekly occurrences (18mo window)")
    }

    @Test func whenMonthlyBillOverdueAlmostTwoYears_thenIncludesWithinWindow() throws {
        let (bill, _) = try makeSUT(
            dueDate: makeDate(year: 2023, month: 9, day: 1),
            pattern: .monthly
        )

        let unpaid = bill.unpaidOccurrences(
            aroundDate: makeDate(year: 2025, month: 9, day: 1),  // 24 months later
            calendar: .current
        )

        let septemberCount = unpaid.filter {
            Calendar.current.component(.month, from: $0) == 9 &&
            Calendar.current.component(.year, from: $0) == 2023
        }.count
        #expect(septemberCount > 0, "Expected Sept 2023 in results (within 24mo window)")
    }

    @Test func whenYearlyBillOverdue5Years_thenIncludesAllInWindow() throws {
        let (bill, _) = try makeSUT(
            dueDate: makeDate(year: 2020, month: 9, day: 15),
            pattern: .yearly
        )

        let unpaid = bill.unpaidOccurrences(
            aroundDate: makeDate(year: 2025, month: 9, day: 1),  // Exactly 60 months later
            calendar: .current
        )

        // 60 month lookback = 5 occurrences (2020, 2021, 2022, 2023, 2024)
        let year2020Count = unpaid.filter {
            Calendar.current.component(.year, from: $0) == 2020 &&
            Calendar.current.component(.month, from: $0) == 9
        }.count
        #expect(year2020Count > 0, "Expected Sept 2020 in results (within 60mo window)")
        #expect(unpaid.count >= 5, "Expected at least 5 yearly occurrences")
    }
}

// MARK: - makeSUT & Factories

private func makeSUT(
    dueDate: Date,
    pattern: RepeatIntervalType
) throws -> (Bill, ModelContext) {
    let schema = Schema([Bill.self, Payment.self, RecurrenceRule.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    let context = ModelContext(container)

    let rule = RecurrenceRule(
        pattern: pattern,
        frequency: 1
    )
    let bill = Bill(
        name: "Test Bill",
        amount: 100,
        dueDate: dueDate,
        recurrenceRule: rule
    )

    context.insert(bill)
    try context.save()

    return (bill, context)
}

private func makeDate(year: Int = 2025, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return Calendar.current.date(from: components)!
}
