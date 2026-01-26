//  Created by Jiri Urbasek on 12/04/25.

import Foundation
import Testing
import SwiftData
@testable import Billo

@Suite("AppNotificationRefresher")
@MainActor
struct AppNotificationRefresherTests {

    @Test
    func whenRefreshingOnActivation_thenRefreshesBillsAndSchedulesUsingRefreshedBills() async throws {
        let billFixture = try makeBillFixture(dueDate: makeDate(year: 2025, month: 12, day: 3))
        let (sut, billsModel, coordinator) = makeSUT(
            initialBills: [],
            billsAfterRefresh: [billFixture.bill],
            refreshResult: .succeeds
        )

        await sut.refreshAndReschedule(billsModel: billsModel, coordinator: coordinator)

        #expect(billsModel.refreshCallCount == 1)
        let scheduledBills = try #require(coordinator.refreshAllNotificationsCalls.first)
        #expect(billIDStrings(scheduledBills) == [billFixture.billIDString])
    }

    @Test
    func whenRefreshBillsIsFalse_thenDoesNotRefreshAndSchedulesUsingCurrentBills() async throws {
        let billFixture = try makeBillFixture(dueDate: makeDate(year: 2025, month: 12, day: 3))
        let (sut, billsModel, coordinator) = makeSUT(
            initialBills: [billFixture.bill],
            billsAfterRefresh: [],
            refreshResult: .succeeds
        )

        await sut.refreshAndReschedule(billsModel: billsModel, coordinator: coordinator, refreshBills: false)

        #expect(billsModel.refreshCallCount == 0)
        let scheduledBills = try #require(coordinator.refreshAllNotificationsCalls.first)
        #expect(billIDStrings(scheduledBills) == [billFixture.billIDString])
    }

    @Test
    func whenBillsRefreshThrows_thenStillSchedulesUsingCurrentBills() async throws {
        let billFixture = try makeBillFixture(dueDate: makeDate(year: 2025, month: 12, day: 3))
        let (sut, billsModel, coordinator) = makeSUT(
            initialBills: [billFixture.bill],
            billsAfterRefresh: [],
            refreshResult: .fails(TestError())
        )

        await sut.refreshAndReschedule(billsModel: billsModel, coordinator: coordinator)

        #expect(billsModel.refreshCallCount == 1)
        let scheduledBills = try #require(coordinator.refreshAllNotificationsCalls.first)
        #expect(billIDStrings(scheduledBills) == [billFixture.billIDString])
    }

    @Test
    func whenCoordinatorRefreshThrows_thenStillRefreshesBillsAndAttemptsScheduling() async throws {
        let billFixture = try makeBillFixture(dueDate: makeDate(year: 2025, month: 12, day: 3))
        let (sut, billsModel, coordinator) = makeSUT(
            initialBills: [],
            billsAfterRefresh: [billFixture.bill],
            refreshResult: .succeeds,
            coordinatorError: TestError()
        )

        await sut.refreshAndReschedule(billsModel: billsModel, coordinator: coordinator)

        #expect(billsModel.refreshCallCount == 1)
        #expect(coordinator.refreshAllNotificationsCalls.count == 1)
    }

    // MARK: - Helpers

    private func makeSUT(
        initialBills: [Bill],
        billsAfterRefresh: [Bill],
        refreshResult: BillsRefreshingTestDouble.RefreshResult,
        coordinatorError: (any Error)? = nil
    ) -> (sut: AppNotificationRefresher, billsModel: BillsRefreshingTestDouble, coordinator: NotificationCoordinatorSpy) {
        let billsModel = BillsRefreshingTestDouble(
            initialBills: initialBills,
            billsAfterRefresh: billsAfterRefresh,
            refreshResult: refreshResult
        )

        let coordinator = NotificationCoordinatorSpy()
        coordinator.refreshAllNotificationsError = coordinatorError

        return (AppNotificationRefresher(), billsModel, coordinator)
    }

    private func makeBillFixture(
        dueDate: Date,
        recurrence: RepeatIntervalType? = nil
    ) throws -> (bill: Bill, billIDString: String) {
        let schema = Schema([Bill.self, PaymentEntry.self, IssuedOccurrence.self, RecurrenceRule.self])
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

        return (bill, bill.stableID)
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func billIDStrings(_ bills: [Bill]) -> [String] {
        bills.map(\.stableID)
    }
}

// MARK: - Test Doubles

@MainActor
private final class BillsRefreshingTestDouble: BillsRefreshing, @unchecked Sendable {
    enum RefreshResult {
        case succeeds
        case fails(any Error)
    }

    private(set) var refreshCallCount = 0
    private(set) var bills: [Bill]
    private let billsAfterRefresh: [Bill]
    private let refreshResult: RefreshResult

    init(
        initialBills: [Bill],
        billsAfterRefresh: [Bill],
        refreshResult: RefreshResult
    ) {
        self.bills = initialBills
        self.billsAfterRefresh = billsAfterRefresh
        self.refreshResult = refreshResult
    }

    func refresh() throws {
        refreshCallCount += 1
        switch refreshResult {
        case .succeeds:
            bills = billsAfterRefresh
        case .fails(let error):
            throw error
        }
    }
}

private struct TestError: Error { }
