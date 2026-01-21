//  Created by Jiri Urbasek on 11/26/25.

import Testing
import SwiftData
import Foundation
@testable import Billo

@Suite("BillsModel")
struct BillsModelTests {

    @MainActor
    @Suite("refresh")
    struct Refresh {
        @Test func whenRefreshed_thenFetchesBillsFromModelContext() throws {
            let (sut, _, _, _, _) = try makeSUT(billCount: 3)

            try sut.refresh()

            #expect(sut.bills.count == 3)
            #expect(sut.bills.map(\.name) == ["Bill 1", "Bill 2", "Bill 3"])
        }

        @Test func whenRefreshed_thenBuildsSections() throws {
            let (sut, _, _, _, _) = try makeSUT(billCount: 2)

            try sut.refresh()

            #expect(sut.sections.occurrencesBySection.isEmpty == false)
        }
    }

    @MainActor
    @Suite("markPaid")
    struct MarkPaid {
        @Test func when_markPaidCalled_then_occurrenceStatusUpdated() async throws {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            calendar.locale = Locale(identifier: "en_US")
            let referenceDate = makeDate(year: 2025, month: 1, day: 15)
            let (sut, bills, _, _, _) = try makeSUT(
                billCount: 1,
                referenceDate: referenceDate,
                calendar: calendar
            )
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])

            try await sut.markPaid(occurrence)

            #expect(bills[0].status(relativeTo: referenceDate, calendar: calendar) == .paid)
        }

        @Test func when_markPaidCalled_then_paymentRecordCreated() async throws {
            let (sut, bills, modelContext, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])

            try await sut.markPaid(occurrence)

            let payments = try modelContext.fetch(FetchDescriptor<Payment>())
            #expect(payments.count == 1)
            #expect(payments.first?.bill?.id == bills[0].id)
            #expect(payments.first?.occurrenceDate == occurrence.dueDate)
        }

        @Test func whenMarkingOccurrencePaid_thenCreatesPayment() async throws {
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])

            try await sut.markPaid(occurrence)

            #expect(bills[0].payments.count == 1)
            #expect(bills[0].payments[0].amount == bills[0].amount)
        }

        @Test func whenMarkingPaidWithCustomAmount_thenUsesCustomAmount() async throws {
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])
            let customAmount = Decimal(75)

            try await sut.markPaid(occurrence, amount: customAmount)

            #expect(bills[0].payments[0].amount == customAmount)
        }

        @Test func whenMarkingPaidWithConfirmation_thenStoresConfirmationNumber() async throws {
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])

            try await sut.markPaid(occurrence, confirmationNumber: "CONF123")

            #expect(bills[0].payments[0].confirmationNumber == "CONF123")
        }

        @Test func whenMarkingPaid_thenRefreshesSections() async throws {
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])

            try await sut.markPaid(occurrence)

            let allOccurrences = sut.sections.occurrencesBySection.values.flatMap { $0 }
            #expect(allOccurrences.isEmpty)
        }

        @Test func whenMarkingPaid_thenMonthlyTotalsReflectPayment() async throws {
            let referenceDate = makeDate(year: 2025, month: 1, day: 20)
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1, referenceDate: referenceDate)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])

            #expect(sut.sections.monthlyTotals.remaining == bills[0].amount)

            try await sut.markPaid(occurrence)

            #expect(sut.sections.monthlyTotals.totalPaid == bills[0].amount)
            #expect(sut.sections.monthlyTotals.remaining == 0)
        }

        @Test func whenMarkingPaid_thenCancelsRemindersAndUpdatesBadge() async throws {
            let (sut, bills, _, coordinator, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])

            try await sut.markPaid(occurrence)

            #expect(coordinator.cancelRemindersCalls.contains(where: { $0.contains(occurrence.id) }))
            #expect(coordinator.updateBadgeCalls.last == 0)
            #expect(coordinator.refreshAllNotificationsCalls.count == 1)
        }
    }

    @MainActor
    @Suite("markUnpaid")
    struct MarkUnpaid {
        @Test func whenMarkingOccurrenceUnpaid_thenRemovesPayment() async throws {
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])
            try await sut.markPaid(occurrence)

            try await sut.markUnpaid(occurrence)

            #expect(bills[0].payments.isEmpty)
        }

        @Test func whenMarkingUnpaid_thenRefreshesSections() async throws {
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])
            try await sut.markPaid(occurrence)

            try await sut.markUnpaid(occurrence)

            let allOccurrences = sut.sections.occurrencesBySection.values.flatMap { $0 }
            #expect(allOccurrences.count == 1)
        }

        @Test func whenMarkingUnpaid_thenMonthlyTotalsIncrease() async throws {
            let referenceDate = makeDate(year: 2025, month: 1, day: 18)
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1, referenceDate: referenceDate)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])
            try await sut.markPaid(occurrence)
            #expect(sut.sections.monthlyTotals.remaining == 0)

            try await sut.markUnpaid(occurrence)

            #expect(sut.sections.monthlyTotals.totalPaid == 0)
            #expect(sut.sections.monthlyTotals.remaining == bills[0].amount)
        }

        @Test func whenMarkingUnpaid_thenSchedulesRemindersAndUpdatesBadge() async throws {
            let (sut, bills, _, coordinator, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])
            try await sut.markPaid(occurrence) // create payment first
            let initialRefreshCount = coordinator.refreshAllNotificationsCalls.count

            try await sut.markUnpaid(occurrence)

            #expect(coordinator.scheduleRemindersCalls.last?.contains(where: { $0.id == occurrence.id }) == true)
            #expect(coordinator.updateBadgeCalls.last == 1)
            #expect(coordinator.refreshAllNotificationsCalls.count == initialRefreshCount + 1)
        }
    }

    @MainActor
    @Suite("deleteBill")
    struct DeleteBill {
        @Test func whenDeletingBill_thenRemovesFromModelContext() async throws {
            let (sut, bills, modelContext, _, _) = try makeSUT(billCount: 2)
            try sut.refresh()

            try await sut.deleteBill(bills[0])

            let descriptor = FetchDescriptor<Bill>()
            let remainingBills = try modelContext.fetch(descriptor)
            #expect(remainingBills.count == 1)
            #expect(remainingBills[0].name == "Bill 2")
        }

        @Test func whenDeletingBill_thenRefreshesList() async throws {
            let (sut, bills, _, _, _) = try makeSUT(billCount: 2)
            try sut.refresh()

            try await sut.deleteBill(bills[0])

            #expect(sut.bills.count == 1)
            #expect(sut.bills[0].name == "Bill 2")
        }

        @Test func whenDeletingBill_thenRefreshesNotifications() async throws {
            let (sut, bills, _, coordinator, _) = try makeSUT(billCount: 2)
            try sut.refresh()

            try await sut.deleteBill(bills[0])

            #expect(coordinator.refreshAllNotificationsCalls.count == 1)
        }
    }

    @MainActor
    @Suite("addBill")
    struct AddBill {
        @Test func whenAddingBill_thenInsertsAndRefreshesNotifications() async throws {
            let (sut, _, modelContext, coordinator, _) = try makeSUT(billCount: 0)

            let dueDate = makeDate(year: 2025, month: 1, day: 20)
            let newBill = Bill(name: "New Bill", amount: Decimal(50), dueDate: dueDate)

            try await sut.addBill(newBill)

            let bills = try modelContext.fetch(FetchDescriptor<Bill>())
            #expect(bills.count == 1 && bills.first?.name == "New Bill")
            #expect(coordinator.refreshAllNotificationsCalls.count == 1)
        }
    }

    @MainActor
    @Suite("updateBill")
    struct UpdateBill {
        @Test func whenUpdatingBill_thenRefreshesNotifications() async throws {
            let (sut, bills, _, coordinator, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let bill = bills[0]
            bill.dueDate = Calendar.current.date(byAdding: .day, value: 10, to: bill.dueDate)!

            try await sut.updateBill(bill)

            #expect(coordinator.refreshAllNotificationsCalls.count == 1)
        }
    }
}

// MARK: - makeSUT & Factories

@MainActor
private func makeSUT(
    billCount: Int,
    referenceDate: Date = makeDate(year: 2025, month: 1, day: 15),
    calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.locale = Locale(identifier: "en_US")
        return cal
    }()
) throws -> (
    BillsModel,
    [Bill],
    ModelContext,
    NotificationCoordinatorSpy,
    NotificationPreferencesStub
) {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Bill.self, Payment.self, configurations: config)
    let modelContext = ModelContext(container)

    let bills: [Bill]
    if billCount > 0 {
        bills = (1...billCount).map { index in
            let dueDate = calendar.date(byAdding: .day, value: index, to: referenceDate)!

            let bill = Bill(
                name: "Bill \(index)",
                amount: Decimal(100),
                dueDate: dueDate
            )
            modelContext.insert(bill)
            return bill
        }
    } else {
        bills = []
    }

    try modelContext.save()

    let coordinator = NotificationCoordinatorSpy()
    let preferences = NotificationPreferencesStub()

    let sut = BillsModel(
        modelContext: modelContext,
        calendar: calendar,
        currentDate: { referenceDate },
        notificationCoordinator: coordinator,
        notificationPreferences: preferences
    )

    return (sut, bills, modelContext, coordinator, preferences)
}

private func makeDate(year: Int = 2025, month: Int = 1, day: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.locale = Locale(identifier: "en_US")
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return calendar.date(from: components)!
}

@MainActor
private func makeOccurrence(for bill: Bill, dueDate: Date? = nil) -> BillOccurrence {
    BillOccurrence(bill: bill, dueDate: dueDate ?? bill.dueDate)
}

// MARK: - Test Doubles
