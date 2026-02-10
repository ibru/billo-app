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

            let payments = try modelContext.fetch(FetchDescriptor<PaymentEntry>())
            #expect(payments.count == 1)
            #expect(payments.first?.bill?.id == bills[0].id)
            #expect(payments.first?.occurrenceDate == occurrence.dueDate)
        }

        @Test func whenMarkingOccurrencePaid_thenCreatesPayment() async throws {
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])

            try await sut.markPaid(occurrence)

            #expect(bills[0].allPaymentEntries.count == 1)
            #expect(bills[0].allPaymentEntries.first?.amount == bills[0].amount)
        }

        @Test func whenMarkingOccurrencePaid_thenPaymentSnapshotsBillData() async throws {
            let (sut, bills, modelContext, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let bill = bills[0]
            let occurrence = makeOccurrence(for: bill)

            try await sut.markPaid(occurrence)

            let issuedOccurrences = try modelContext.fetch(FetchDescriptor<IssuedOccurrence>())
            let issued = issuedOccurrences.first

            #expect(issued?.billName == bill.name)
            #expect(issued?.billAmount == bill.amount)
            #expect(issued?.billCurrencyCode == bill.currencyCode)
        }

        @Test func whenBillUpdatedAfterPayment_thenOccurrenceUsesPaymentSnapshot() async throws {
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

            let bill = bills[0]
            let occurrence = makeOccurrence(for: bill)

            try await sut.markPaid(occurrence)

            bill.amount = 150
            try await sut.updateBill(bill)

            let updatedOccurrence = BillOccurrence(bill: bill, dueDate: occurrence.dueDate, calendar: calendar)
            #expect(updatedOccurrence.amount == 100)
        }

        @Test func whenMarkingPaidWithCustomAmount_thenUsesCustomAmount() async throws {
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])
            let customAmount = Decimal(75)

            try await sut.markPaid(occurrence, amount: customAmount)

            #expect(bills[0].allPaymentEntries.first?.amount == customAmount)
        }

        @Test func whenMarkingPaidWithConfirmation_thenStoresConfirmationNumber() async throws {
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])

            try await sut.markPaid(occurrence, confirmationNumber: "CONF123")

            #expect(bills[0].allPaymentEntries.first?.confirmationNumber == "CONF123")
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

            #expect(bills[0].allPaymentEntries.isEmpty)
        }

        @Test func whenMarkingFutureOccurrenceUnpaid_thenRemovesIssuedOccurrence() async throws {
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])
            try await sut.markPaid(occurrence)
            #expect(bills[0].safeIssuedOccurrences.isEmpty == false)

            try await sut.markUnpaid(occurrence)

            #expect(bills[0].safeIssuedOccurrences.isEmpty)
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

        @Test func whenMarkingUnpaid_thenRefreshesNotifications() async throws {
            let (sut, bills, _, coordinator, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])
            try await sut.markPaid(occurrence) // create payment first
            let initialRefreshCount = coordinator.refreshAllNotificationsCalls.count

            try await sut.markUnpaid(occurrence)

            // markUnpaid now uses full refresh instead of individual schedule/badge calls
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

        @Test func whenDeletingBill_thenNullifiesIssuedOccurrencesBillReferenceButPreservesPaymentHistory() async throws {
            let (sut, bills, modelContext, _, _) = try makeSUT(billCount: 1)
            let bill = bills[0]
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            calendar.locale = Locale(identifier: "en_US")
            let datePaid = bill.dueDate

            _ = makePaymentEntry(
                amount: bill.amount,
                datePaid: datePaid,
                occurrenceDate: bill.dueDate,
                bill: bill,
                calendar: calendar,
                in: modelContext
            )
            try modelContext.save()

            let issuedBefore = try modelContext.fetch(FetchDescriptor<IssuedOccurrence>())
            let paymentsBefore = try modelContext.fetch(FetchDescriptor<PaymentEntry>())
            #expect(issuedBefore.count == 1)
            #expect(paymentsBefore.count == 1)

            try await sut.deleteBill(bill)

            // With .nullify delete rule, IssuedOccurrences and PaymentEntries are preserved for history
            let issuedAfter = try modelContext.fetch(FetchDescriptor<IssuedOccurrence>())
            let paymentsAfter = try modelContext.fetch(FetchDescriptor<PaymentEntry>())
            #expect(issuedAfter.count == 1)
            #expect(paymentsAfter.count == 1)
            // But the bill reference is nil (orphaned)
            #expect(issuedAfter.first?.bill == nil)
        }
    }

    @MainActor
    @Suite("deletePaymentEntry")
    struct DeletePaymentEntry {
        @Test func whenDeletingPayment_thenRemovesFromModelContext() async throws {
            let (sut, bills, modelContext, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])
            try await sut.markPaid(occurrence)

            let paymentsBefore = try modelContext.fetch(FetchDescriptor<PaymentEntry>())
            #expect(paymentsBefore.count == 1)

            let payment = paymentsBefore[0]
            try await sut.deletePaymentEntry(payment)

            let paymentsAfter = try modelContext.fetch(FetchDescriptor<PaymentEntry>())
            #expect(paymentsAfter.isEmpty)
        }

        @Test func whenDeletingPayment_thenRefreshesNotifications() async throws {
            let (sut, bills, _, coordinator, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])
            try await sut.markPaid(occurrence)
            let initialRefreshCount = coordinator.refreshAllNotificationsCalls.count

            let payment = bills[0].allPaymentEntries.first!
            try await sut.deletePaymentEntry(payment)

            #expect(coordinator.refreshAllNotificationsCalls.count == initialRefreshCount + 1)
        }

        @Test func whenDeletingPaymentForFutureOccurrence_thenRemovesIssuedOccurrence() async throws {
            let (sut, bills, modelContext, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])
            try await sut.markPaid(occurrence)

            let issuedBefore = try modelContext.fetch(FetchDescriptor<IssuedOccurrence>())
            #expect(issuedBefore.count == 1)

            let payment = bills[0].allPaymentEntries.first!
            try await sut.deletePaymentEntry(payment)

            let issuedAfter = try modelContext.fetch(FetchDescriptor<IssuedOccurrence>())
            #expect(issuedAfter.isEmpty)
        }

        @Test func whenDeletingPaymentForPastOccurrence_thenKeepsIssuedOccurrence() async throws {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            calendar.locale = Locale(identifier: "en_US")
            let referenceDate = makeDate(year: 2025, month: 1, day: 20)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            // Create bill with past due date
            let pastDueDate = makeDate(year: 2025, month: 1, day: 10)
            let bill = Bill(name: "Past Bill", amount: 100, dueDate: pastDueDate, calendar: calendar)
            modelContext.insert(bill)
            try modelContext.save()
            try sut.refresh()

            let occurrence = makeOccurrence(for: bill, dueDate: pastDueDate)
            try await sut.markPaid(occurrence)

            let issuedBefore = try modelContext.fetch(FetchDescriptor<IssuedOccurrence>())
            #expect(issuedBefore.count == 1)

            let payment = bill.allPaymentEntries.first!
            try await sut.deletePaymentEntry(payment)

            // Past occurrence should keep IssuedOccurrence for historical snapshot
            let issuedAfter = try modelContext.fetch(FetchDescriptor<IssuedOccurrence>())
            #expect(issuedAfter.count == 1)
        }

        @Test func whenDeletingPartialPayment_thenKeepsRemainingPayments() async throws {
            let (sut, bills, modelContext, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let bill = bills[0]
            let occurrence = makeOccurrence(for: bill)

            // Make two partial payments
            try await sut.markPaid(occurrence, amount: 50)
            try await sut.markPaid(occurrence, amount: 30)

            let paymentsBefore = try modelContext.fetch(FetchDescriptor<PaymentEntry>())
            #expect(paymentsBefore.count == 2)

            // Delete one payment
            let paymentToDelete = paymentsBefore[0]
            try await sut.deletePaymentEntry(paymentToDelete)

            let paymentsAfter = try modelContext.fetch(FetchDescriptor<PaymentEntry>())
            #expect(paymentsAfter.count == 1)

            let issuedAfter = try modelContext.fetch(FetchDescriptor<IssuedOccurrence>())
            #expect(issuedAfter.count == 1)
        }

        @Test func whenDeletingPayment_thenRefreshesSections() async throws {
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])
            try await sut.markPaid(occurrence)

            // After marking paid, sections should have no occurrences
            #expect(sut.sections.occurrencesBySection.values.flatMap { $0 }.isEmpty)

            let payment = bills[0].allPaymentEntries.first!
            try await sut.deletePaymentEntry(payment)

            // After deleting payment, the occurrence should reappear
            #expect(sut.sections.occurrencesBySection.values.flatMap { $0 }.count == 1)
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

        @Test func whenEditingPastDueOccurrence_thenIssuesSnapshotFromPreEditValues() async throws {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            calendar.locale = Locale(identifier: "en_US")
            let referenceDate = makeDate(year: 2025, month: 1, day: 15)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            let pastDueDate = makeDate(year: 2025, month: 1, day: 1)
            let bill = Bill(name: "Original Name", amount: 100, dueDate: pastDueDate, calendar: calendar)
            modelContext.insert(bill)
            try modelContext.save()
            try sut.refresh()

            let preEditSnapshot = BillSnapshot(bill: bill)
            bill.name = "Updated Name"
            bill.amount = 150
            bill.lastUpdatedDate = referenceDate

            try await sut.updateBill(bill, preEditSnapshot: preEditSnapshot)

            let issued = try modelContext.fetch(FetchDescriptor<IssuedOccurrence>())
            #expect(issued.count == 1)
            #expect(issued.first?.billName == "Original Name")
            #expect(issued.first?.billAmount == 100)

            let occurrence = BillOccurrence(bill: bill, dueDate: pastDueDate, calendar: calendar)
            #expect(occurrence.name == "Original Name")
            #expect(occurrence.amount == 100)
        }

        @Test func whenEditingRecurringBillWithMultiplePastOccurrences_thenIssuesEachUnpaidOccurrence() async throws {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            calendar.locale = Locale(identifier: "en_US")
            let referenceDate = makeDate(year: 2025, month: 1, day: 15)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            let pastDueDate = makeDate(year: 2024, month: 10, day: 1)
            let bill = Bill(name: "Streaming", amount: 40, dueDate: pastDueDate, calendar: calendar)
            let rule = RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 1)
            bill.recurrenceRule = rule
            modelContext.insert(bill)
            try modelContext.save()
            try sut.refresh()

            let preEditSnapshot = BillSnapshot(bill: bill)
            bill.amount = 45

            try await sut.updateBill(bill, preEditSnapshot: preEditSnapshot)

            let issued = try modelContext.fetch(FetchDescriptor<IssuedOccurrence>())
            let issuedDays = issued.map { calendar.startOfDay(for: $0.dueDate) }
            let expectedDays = [
                makeDate(year: 2024, month: 10, day: 1),
                makeDate(year: 2024, month: 11, day: 1),
                makeDate(year: 2024, month: 12, day: 1),
                makeDate(year: 2025, month: 1, day: 1)
            ]

            #expect(issued.count == 4)
            #expect(Set(issuedDays) == Set(expectedDays))
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
    let container = try ModelContainer(
        for: Bill.self,
        PaymentEntry.self,
        IssuedOccurrence.self,
        RecurrenceRule.self,
        configurations: config
    )
    let modelContext = ModelContext(container)

    let bills: [Bill]
    if billCount > 0 {
        bills = (1...billCount).map { index in
            let dueDate = calendar.date(byAdding: .day, value: index, to: referenceDate)!

            let bill = Bill(
                name: "Bill \(index)",
                amount: Decimal(100),
                dueDate: dueDate,
                calendar: calendar
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
