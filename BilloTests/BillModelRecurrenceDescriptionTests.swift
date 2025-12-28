//  Created by Jiri Urbasek on 12/28/25.

import Foundation
import SwiftData
import Testing
@testable import Billo

@MainActor
@Suite("BillModel.recurrenceDescription")
struct BillModelRecurrenceDescriptionTests {
    @Test func whenWeeklyWithFrequencyOneAndWeekday_thenReturnsWeeklyOnWeekday() throws {
        let locale = Locale(identifier: "en_US")
        let rule = RecurrenceRule(pattern: .weekly, frequency: 1, dayOfWeek: .monday)
        let sut = try makeSUT(recurrenceRule: rule)

        let description = sut.recurrenceDescription(locale: locale)

        #expect(description == "Weekly on Monday")
    }

    @Test func whenMonthlyWithFrequencyOneAndDayOfMonthOne_thenUsesLocalizedOrdinal() throws {
        let locale = Locale(identifier: "en_US")
        let rule = RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 1)
        let sut = try makeSUT(recurrenceRule: rule)

        let description = sut.recurrenceDescription(locale: locale)

        #expect(description == "Monthly on the 1st")
    }

    @Test func whenYearlyWithFrequencyTwo_thenReturnsEveryNYears() throws {
        let locale = Locale(identifier: "en_US")
        let rule = RecurrenceRule(pattern: .yearly, frequency: 2)
        let sut = try makeSUT(recurrenceRule: rule)

        let description = sut.recurrenceDescription(locale: locale)

        #expect(description == "Every 2 years")
    }
}

// MARK: - makeSUT

@MainActor
private func makeSUT(recurrenceRule: RecurrenceRule) throws -> BillModel {
    let schema = Schema([Bill.self, Payment.self, RecurrenceRule.self])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let modelContext = ModelContext(container)

    let bill = Bill(
        name: "Test Bill",
        amount: 100,
        currencyCode: "USD",
        dueDate: Date(),
        recurrenceRule: recurrenceRule
    )
    modelContext.insert(bill)

    return BillModel(bill: bill, modelContext: modelContext)
}
