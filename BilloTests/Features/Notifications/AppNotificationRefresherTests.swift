//  Created by Jiri Urbasek on 12/04/25.

import Foundation
import Testing
import SwiftData
@testable import Billo

@Suite("AppNotificationRefresher")
@MainActor
struct AppNotificationRefresherTests {

    @Test
    func whenRefreshingOnActivation_thenSchedulesWithLatestBills() async throws {
        let bill = try makeBill(dueDate: makeDate(year: 2025, month: 12, day: 3))
        let billsModel = BillsRefreshingSpy(billsAfterRefresh: [bill])
        let coordinator = NotificationCoordinatorSpy()
        let sut = AppNotificationRefresher()

        await sut.refreshAndReschedule(billsModel: billsModel, coordinator: coordinator)

        #expect(billsModel.refreshCallCount == 1)
        #expect(
            coordinator.refreshAllNotificationsCalls.first?.map { String(describing: $0.persistentModelID) }
            == [String(describing: bill.persistentModelID)]
        )
    }

    // MARK: - Helpers

    private func makeBill(
        dueDate: Date,
        recurrence: RepeatIntervalType? = nil
    ) throws -> Bill {
        let schema = Schema([Bill.self, Payment.self, RecurrenceRule.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let rule = recurrence.map { RecurrenceRule(pattern: $0, frequency: 1) }
        let bill = Bill(
            name: "Overdue Bill",
            amount: 42,
            dueDate: dueDate,
            recurrenceRule: rule
        )

        context.insert(bill)
        try context.save()

        return bill
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))!
    }
}

// MARK: - Test Doubles

@MainActor
private final class BillsRefreshingSpy: BillsRefreshing, @unchecked Sendable {
    var billsAfterRefresh: [Bill]
    private(set) var refreshCallCount = 0
    private(set) var bills: [Bill] = []

    init(billsAfterRefresh: [Bill]) {
        self.billsAfterRefresh = billsAfterRefresh
    }

    func refresh() throws {
        refreshCallCount += 1
        bills = billsAfterRefresh
    }
}
