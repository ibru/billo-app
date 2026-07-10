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

        @Test func whenBillsCategorized_thenRefreshCachesUsageCounts() throws {
            let (sut, bills, context, _, _) = try makeSUT(billCount: 3)
            bills[0].categoryIdentifier = .predefined(.utilities)
            bills[1].categoryIdentifier = .predefined(.utilities)
            bills[2].categoryIdentifier = .custom("custom-1")
            try context.save()

            try sut.refresh()

            #expect(sut.categoryUsageCounts == [
                .predefined(.utilities): 2,
                .custom("custom-1"): 1
            ])
        }

        @Test func whenBillDeleted_thenRefreshDropsItsUsageCount() async throws {
            let (sut, bills, context, _, _) = try makeSUT(billCount: 2)
            bills[0].categoryIdentifier = .predefined(.pets)
            bills[1].categoryIdentifier = .predefined(.pets)
            try context.save()
            try sut.refresh()

            try await sut.deleteBill(bills[0])

            #expect(sut.categoryUsageCounts == [.predefined(.pets): 1])
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

            try await sut.markPaid(occurrence, source: .sheet)

            #expect(bills[0].status(relativeTo: referenceDate, calendar: calendar) == .paid)
        }

        @Test func when_markPaidCalled_then_paymentRecordCreated() async throws {
            let (sut, bills, modelContext, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])

            try await sut.markPaid(occurrence, source: .sheet)

            let payments = try modelContext.fetch(FetchDescriptor<PaymentEntry>())
            #expect(payments.count == 1)
            #expect(payments.first?.bill?.id == bills[0].id)
            #expect(payments.first?.occurrenceDate == occurrence.dueDate)
        }

        @Test func whenMarkingOccurrencePaid_thenCreatesPayment() async throws {
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])

            try await sut.markPaid(occurrence, source: .sheet)

            #expect(bills[0].allPaymentEntries.count == 1)
            #expect(bills[0].allPaymentEntries.first?.amount == bills[0].amount)
        }

        @Test func whenMarkingOccurrencePaid_thenPaymentSnapshotsBillData() async throws {
            let (sut, bills, modelContext, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let bill = bills[0]
            let occurrence = makeOccurrence(for: bill)

            try await sut.markPaid(occurrence, source: .sheet)

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

            try await sut.markPaid(occurrence, source: .sheet)

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

            try await sut.markPaid(occurrence, amount: customAmount, source: .sheet)

            #expect(bills[0].allPaymentEntries.first?.amount == customAmount)
        }

        @Test func whenMarkingPaidWithConfirmation_thenStoresConfirmationNumber() async throws {
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])

            try await sut.markPaid(occurrence, confirmationNumber: "CONF123", source: .sheet)

            #expect(bills[0].allPaymentEntries.first?.confirmationNumber == "CONF123")
        }

        @Test func whenMarkingPaid_thenRefreshesSections() async throws {
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])

            try await sut.markPaid(occurrence, source: .sheet)

            let allOccurrences = sut.sections.occurrencesBySection.values.flatMap { $0 }
            #expect(allOccurrences.isEmpty)
        }

        @Test func whenMarkingPaid_thenMonthlyTotalsReflectPayment() async throws {
            let referenceDate = makeDate(year: 2025, month: 1, day: 20)
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1, referenceDate: referenceDate)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])

            #expect(sut.sections.monthlyTotals.remaining == bills[0].amount)

            try await sut.markPaid(occurrence, source: .sheet)

            #expect(sut.sections.monthlyTotals.totalPaid == bills[0].amount)
            #expect(sut.sections.monthlyTotals.remaining == 0)
        }

        @Test func whenMarkingPaid_thenCancelsRemindersAndUpdatesBadge() async throws {
            let (sut, bills, _, coordinator, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])

            try await sut.markPaid(occurrence, source: .sheet)

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
            try await sut.markPaid(occurrence, source: .sheet)

            try await sut.markUnpaid(occurrence)

            #expect(bills[0].allPaymentEntries.isEmpty)
        }

        @Test func whenMarkingFutureOccurrenceUnpaid_thenRemovesIssuedOccurrence() async throws {
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])
            try await sut.markPaid(occurrence, source: .sheet)
            #expect(bills[0].safeIssuedOccurrences.isEmpty == false)

            try await sut.markUnpaid(occurrence)

            #expect(bills[0].safeIssuedOccurrences.isEmpty)
        }

        @Test func whenMarkingUnpaid_thenRefreshesSections() async throws {
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])
            try await sut.markPaid(occurrence, source: .sheet)

            try await sut.markUnpaid(occurrence)

            let allOccurrences = sut.sections.occurrencesBySection.values.flatMap { $0 }
            #expect(allOccurrences.count == 1)
        }

        @Test func whenMarkingUnpaid_thenMonthlyTotalsIncrease() async throws {
            let referenceDate = makeDate(year: 2025, month: 1, day: 18)
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1, referenceDate: referenceDate)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])
            try await sut.markPaid(occurrence, source: .sheet)
            #expect(sut.sections.monthlyTotals.remaining == 0)

            try await sut.markUnpaid(occurrence)

            #expect(sut.sections.monthlyTotals.totalPaid == 0)
            #expect(sut.sections.monthlyTotals.remaining == bills[0].amount)
        }

        @Test func whenMarkingUnpaid_thenRefreshesNotifications() async throws {
            let (sut, bills, _, coordinator, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])
            try await sut.markPaid(occurrence, source: .sheet) // create payment first
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
            try await sut.markPaid(occurrence, source: .sheet)

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
            try await sut.markPaid(occurrence, source: .sheet)
            let initialRefreshCount = coordinator.refreshAllNotificationsCalls.count

            let payment = bills[0].allPaymentEntries.first!
            try await sut.deletePaymentEntry(payment)

            #expect(coordinator.refreshAllNotificationsCalls.count == initialRefreshCount + 1)
        }

        @Test func whenDeletingPaymentForFutureOccurrence_thenRemovesIssuedOccurrence() async throws {
            let (sut, bills, modelContext, _, _) = try makeSUT(billCount: 1)
            try sut.refresh()

            let occurrence = makeOccurrence(for: bills[0])
            try await sut.markPaid(occurrence, source: .sheet)

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
            try await sut.markPaid(occurrence, source: .sheet)

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
            try await sut.markPaid(occurrence, amount: 50, source: .sheet)
            try await sut.markPaid(occurrence, amount: 30, source: .sheet)

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
            try await sut.markPaid(occurrence, source: .sheet)

            // After marking paid, sections should have no occurrences
            #expect(sut.sections.occurrencesBySection.values.flatMap { $0 }.isEmpty)

            let payment = bills[0].allPaymentEntries.first!
            try await sut.deletePaymentEntry(payment)

            // After deleting payment, the occurrence should reappear
            #expect(sut.sections.occurrencesBySection.values.flatMap { $0 }.count == 1)
        }
    }

    @MainActor
    @Suite("analytics capture")
    struct AnalyticsCapture {
        @Test func whenAddingBill_thenCapturesBillCreated() async throws {
            var captured: [AnalyticsEvent] = []
            let (sut, _, _, _, _) = try makeSUT(billCount: 0, analyticsCapture: { captured.append($0) })

            let bill = Bill(name: "Internet", amount: Decimal(60), dueDate: makeDate(day: 20))
            bill.categoryIdentifier = .predefined(.utilities)
            try await sut.addBill(bill)

            #expect(captured.count == 1)
            #expect(captured.first?.name == "bill created")
            #expect(captured.first?.properties["category"] as? String == "default.utilities")
            #expect(captured.first?.properties["is_recurring"] as? Bool == false)
            #expect(captured.first?.properties["amount"] == nil)
        }

        @Test func whenMarkingPaidLate_thenCapturesPaymentRecordedWithSourceAndDaysFromDue() async throws {
            var captured: [AnalyticsEvent] = []
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1, analyticsCapture: { captured.append($0) })
            try sut.refresh()

            // Bill 1 is due one day after the reference date; pay 3 days after due.
            let occurrence = BillOccurrence(bill: bills[0], dueDate: bills[0].dueDate)
            let paidDate = Calendar.current.date(byAdding: .day, value: 3, to: bills[0].dueDate)!
            try await sut.markPaid(occurrence, date: paidDate, source: .listSwipe)

            let event = captured.first { $0.name == "payment recorded" }
            #expect(event != nil)
            #expect(event?.properties["source"] as? String == "list_swipe")
            #expect(event?.properties["days_from_due"] as? Int == 3)
            #expect(event?.properties["is_partial"] as? Bool == false)
        }

        @Test func whenDeletingBillWithPayments_thenCapturesBillDeletedWithHadPayments() async throws {
            var captured: [AnalyticsEvent] = []
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1, analyticsCapture: { captured.append($0) })
            try sut.refresh()

            let occurrence = BillOccurrence(bill: bills[0], dueDate: bills[0].dueDate)
            try await sut.markPaid(occurrence, source: .sheet)
            try await sut.deleteBill(bills[0])

            let event = captured.first { $0.name == "bill deleted" }
            #expect(event?.properties["had_payments"] as? Bool == true)
        }

        @Test func whenReschedulingBill_thenCapturesBillUpdatedWithRescheduledFlag() async throws {
            var captured: [AnalyticsEvent] = []
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1, analyticsCapture: { captured.append($0) })
            try sut.refresh()

            let bill = bills[0]
            let preEditSnapshot = BillSnapshot(bill: bill)
            bill.dueDate = Calendar.current.date(byAdding: .day, value: 10, to: bill.dueDate)!
            try await sut.updateBill(bill, preEditSnapshot: preEditSnapshot)

            let event = captured.first { $0.name == "bill updated" }
            #expect(event?.properties["rescheduled"] as? Bool == true)
        }

        @Test func whenSkippingIncomeOccurrence_thenCapturesSkipped() async throws {
            var captured: [AnalyticsEvent] = []
            let (sut, _, modelContext, _, _) = try makeSUT(billCount: 0, analyticsCapture: { captured.append($0) })

            let occurrence = IncomeOccurrence(
                occurrenceKey: "salary-2025-01-01",
                date: makeDate(day: 1),
                incomeName: "Salary",
                incomeAmount: 3000,
                incomeCurrencyCode: "USD",
                income: nil
            )
            modelContext.insert(occurrence)
            try modelContext.save()

            try await sut.skipIncomeOccurrence(occurrence)

            #expect(captured.map(\.name) == ["income occurrence skipped"])
        }

        @Test func whenDeletingIncomeOccurrence_thenCapturesDeletedNotSkipped() async throws {
            var captured: [AnalyticsEvent] = []
            let (sut, _, modelContext, _, _) = try makeSUT(billCount: 0, analyticsCapture: { captured.append($0) })

            let occurrence = IncomeOccurrence(
                occurrenceKey: "salary-2025-01-01",
                date: makeDate(day: 1),
                incomeName: "Salary",
                incomeAmount: 3000,
                incomeCurrencyCode: "USD",
                income: nil
            )
            modelContext.insert(occurrence)
            try modelContext.save()

            try await sut.deleteIncomeOccurrence(occurrence)

            #expect(captured.map(\.name) == ["income occurrence deleted"])
        }

        @Test func whenDeletingPaymentWithNoCategory_thenCapturesNoneCategory() async throws {
            var captured: [AnalyticsEvent] = []
            let (sut, bills, _, _, _) = try makeSUT(billCount: 1, analyticsCapture: { captured.append($0) })
            try sut.refresh()

            let occurrence = BillOccurrence(bill: bills[0], dueDate: bills[0].dueDate)
            try await sut.markPaid(occurrence, source: .sheet)
            let payment = bills[0].allPaymentEntries.first!

            try await sut.deletePaymentEntry(payment)

            let event = captured.first { $0.name == "payment deleted" }
            #expect(event?.properties["category"] as? String == "none")
        }

        @Test func whenAddingIncome_thenCapturesIncomeCreated() async throws {
            var captured: [AnalyticsEvent] = []
            let (sut, _, _, _, _) = try makeSUT(billCount: 0, analyticsCapture: { captured.append($0) })

            let income = try Income.create(
                name: "Salary",
                amount: 3000,
                currencyCode: "USD",
                startDate: makeDate(day: 1),
                recurrenceRule: RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 1)
            )
            try await sut.addIncome(income)

            let event = captured.first { $0.name == "income created" }
            #expect(event?.properties["is_recurring"] as? Bool == true)
            #expect(event?.properties["recurrence_pattern"] as? String == "monthly")
            #expect(event?.properties["amount"] == nil)
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

        @Test func whenMonthlyReschedulingForwardToNewDay_thenPaidPastPreservedAndFutureUsesNewDay() async throws {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            calendar.locale = Locale(identifier: "en_US")
            let today = makeDate(year: 2025, month: 7, day: 1)
            let (sut, _, modelContext, _, _) = try makeSUT(billCount: 0, referenceDate: today, calendar: calendar)

            let anchor = makeDate(year: 2025, month: 2, day: 2)
            let bill = Bill(name: "Gym", amount: 100, dueDate: anchor, calendar: calendar)
            bill.recurrenceRule = RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 2)
            modelContext.insert(bill)
            try modelContext.save()
            try sut.refresh()

            // Pay every past occurrence (Feb–Jun on the 2nd).
            for month in 2...6 {
                try await sut.markPaid(BillOccurrence(bill: bill, dueDate: makeDate(year: 2025, month: month, day: 2), calendar: calendar), source: .sheet)
            }

            // Simulate the edit screen's schedule-change branch: reschedule Jul 2 → Jul 15.
            let preEditSnapshot = BillSnapshot(bill: bill)
            bill.dueDate = calendar.startOfDay(for: makeDate(year: 2025, month: 7, day: 15))
            bill.recurrenceRule = RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 15)
            try await sut.updateBill(bill, preEditSnapshot: preEditSnapshot)

            // Recurrence rule now targets the 15th.
            #expect(bill.recurrenceRule?.dayOfMonth == 15)

            // Paid past occurrences remain fully paid on the 2nd.
            for month in 2...6 {
                #expect(bill.isFullyPaid(for: makeDate(year: 2025, month: month, day: 2), calendar: calendar))
            }

            // Future occurrences now fall on the 15th; the 2nd is no longer generated forward.
            let futureUnpaid = bill.unpaidOccurrences(aroundDate: today, calendar: calendar)
            #expect(futureUnpaid.first == makeDate(year: 2025, month: 7, day: 15))
            #expect(futureUnpaid.contains(makeDate(year: 2025, month: 8, day: 15)))
            #expect(futureUnpaid.contains(makeDate(year: 2025, month: 7, day: 2)) == false)
        }
    }

    @MainActor
    @Suite("income lifecycle")
    struct IncomeLifecycle {
        @Test func whenRefreshIsCalled_thenMissingPastOccurrencesAreMaterialized() throws {
            let calendar = utcCalendar()
            let referenceDate = makeDate(year: 2025, month: 4, day: 10)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            _ = makeMonthlyIncome(
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 1, day: 1),
                in: modelContext
            )
            try modelContext.save()

            try sut.refresh()

            let rows = try modelContext.fetch(FetchDescriptor<IncomeOccurrence>())
            #expect(rows.count == 4) // Jan, Feb, Mar, Apr 1 (all strictly before today=Apr 10)
        }

        @Test func whenIncomeAmountIsUpdated_thenPastOccurrencesKeepOldAmount_AndFutureGenerationUsesNewAmount() async throws {
            let calendar = utcCalendar()
            let referenceDate = makeDate(year: 2025, month: 4, day: 10)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            let income = makeMonthlyIncome(
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 1, day: 1),
                in: modelContext
            )
            try modelContext.save()
            try sut.refresh()

            let draft = IncomeDraft(
                name: income.name,
                amount: 2_000,
                startDate: income.startDate,
                recurrenceRule: income.recurrenceRule
            )
            try await sut.updateIncome(income, draft: draft)

            let pastViews = sut.incomeOccurrenceItems(
                rangeStart: makeDate(year: 2025, month: 1, day: 1),
                rangeEnd: referenceDate
            )
            #expect(pastViews.count == 4)
            #expect(pastViews.allSatisfy { $0.amount == 1_000 })

            let futureViews = sut.incomeOccurrenceItems(
                rangeStart: referenceDate,
                rangeEnd: makeDate(year: 2025, month: 7, day: 1)
            )
            #expect(futureViews.allSatisfy { $0.amount == 2_000 })
            #expect(futureViews.isEmpty == false)
        }

        @Test func whenScheduleEdited_thenPastRowsAreFrozenAndNoNewSchedulePastRowsAreInserted() async throws {
            let calendar = utcCalendar()
            let referenceDate = makeDate(year: 2025, month: 4, day: 10)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            let income = makeMonthlyIncome(
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 1, day: 1),
                in: modelContext
            )
            try modelContext.save()
            try sut.refresh()

            let draft = IncomeDraft(
                name: income.name,
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 1, day: 15),
                recurrenceRule: income.recurrenceRule
            )
            try await sut.updateIncome(income, draft: draft)

            let allRows = try modelContext.fetch(FetchDescriptor<IncomeOccurrence>())
            let oldDayRows = allRows.filter { calendar.component(.day, from: $0.date) == 1 }
            let newDayRows = allRows.filter { calendar.component(.day, from: $0.date) == 15 }

            // Pre-edit produced 4 frozen rows on the 1st (Jan, Feb, Mar, Apr 1).
            // Post-edit refresh must NOT introduce 15th-of-month past rows —
            // snapshot-and-go: the new schedule applies going forward only.
            #expect(oldDayRows.count == 4)
            #expect(oldDayRows.allSatisfy { $0.incomeAmount == 1_000 })
            #expect(newDayRows.isEmpty)
        }

        @Test func whenScheduleEditMovesAnchorToLaterDayInSameMonth_thenNewSchedulePastDatesAreNotBackfilled() async throws {
            // Reviewer-supplied Finding-1 example: old salary on the 1st @ 1000,
            // edited on Apr 10 to the 5th @ 1500. Apr 5 was already past at
            // edit time. Snapshot-and-go says it must NOT be inserted under
            // the new schedule. The previous `latestExistingDate` watermark
            // missed this case because Apr 5 falls strictly between the latest
            // pre-edit row (Apr 1) and today (Apr 10).
            let calendar = utcCalendar()
            let editDay = makeDate(year: 2025, month: 4, day: 10)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: editDay,
                calendar: calendar
            )

            let income = makeMonthlyIncome(
                name: "Salary",
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 1, day: 1),
                in: modelContext
            )
            try modelContext.save()
            try sut.refresh()

            try await sut.updateIncome(
                income,
                draft: IncomeDraft(
                    name: income.name,
                    amount: 1_500,
                    startDate: makeDate(year: 2025, month: 1, day: 5),
                    recurrenceRule: income.recurrenceRule
                )
            )

            let rows = try modelContext
                .fetch(FetchDescriptor<IncomeOccurrence>())
                .sorted { $0.date < $1.date }
            let dayOfMonths = rows.map { calendar.component(.day, from: $0.date) }
            let amounts = rows.map(\.incomeAmount)

            #expect(dayOfMonths == [1, 1, 1, 1])
            #expect(amounts == [1_000, 1_000, 1_000, 1_000])
        }

        @Test func whenScheduleEditedThenTimeAdvancesPastNextOccurrence_thenNewScheduleOccurrenceIsMaterializedAtNewAmount() async throws {
            // Continuation of the Finding-1 example: after the Apr 10 edit, the
            // app keeps running. On May 11 the user reopens and refresh fires.
            // May 5 (the new schedule's first occurrence on or after the edit
            // date) is now in the past and SHOULD be materialized at the new
            // 1500 amount. Final ledger: [Jan 1, Feb 1, Mar 1, Apr 1 @ 1000]
            // plus [May 5 @ 1500].
            let calendar = utcCalendar()
            let editDay = makeDate(year: 2025, month: 4, day: 10)
            let (editSUT, _, modelContext, coordinator, preferences) = try makeSUT(
                billCount: 0,
                referenceDate: editDay,
                calendar: calendar
            )

            let income = makeMonthlyIncome(
                name: "Salary",
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 1, day: 1),
                in: modelContext
            )
            try modelContext.save()
            try editSUT.refresh()

            try await editSUT.updateIncome(
                income,
                draft: IncomeDraft(
                    name: income.name,
                    amount: 1_500,
                    startDate: makeDate(year: 2025, month: 1, day: 5),
                    recurrenceRule: income.recurrenceRule
                )
            )

            // Advance the clock by constructing a second BillsModel over the
            // same context with a later `currentDate`.
            let advancedDate = makeDate(year: 2025, month: 5, day: 11)
            let advancedSUT = BillsModel(
                modelContext: modelContext,
                calendar: calendar,
                currentDate: { advancedDate },
                notificationCoordinator: coordinator,
                notificationPreferences: preferences
            )
            try advancedSUT.refresh()

            let rows = try modelContext
                .fetch(FetchDescriptor<IncomeOccurrence>())
                .sorted { $0.date < $1.date }
            let dayOfMonths = rows.map { calendar.component(.day, from: $0.date) }
            let amounts = rows.map(\.incomeAmount)

            #expect(dayOfMonths == [1, 1, 1, 1, 5])
            #expect(amounts == [1_000, 1_000, 1_000, 1_000, 1_500])
            let mayRow = try #require(rows.last)
            #expect(calendar.component(.month, from: mayRow.date) == 5)
        }

        @Test func whenIncomeEditedSameDayAsOccurrence_thenThatDaysRowIsMaterializedNextDay() async throws {
            // Reviewer Finding-1: salary occurs Apr 1 at midnight, user edits
            // on Apr 1 at noon. The edit must not freeze today's row (the user
            // confirmed `keep current behavior` — today stays live until
            // midnight), but the next-day refresh MUST materialize Apr 1.
            //
            // Pre-fix, `materializationStartDate = currentDate()` stored the
            // precise edit timestamp (Apr 1 12:00). On Apr 2 the materializer
            // compared `Apr 1 00:00 < Apr 1 12:00` and skipped the row
            // forever. Day-normalizing the boundary makes Apr 1 keep equal
            // to the boundary and pass the filter.
            let calendar = utcCalendar()
            let apr1Noon = makeDateTime(year: 2025, month: 4, day: 1, hour: 12)
            let (editSUT, _, modelContext, coordinator, preferences) = try makeSUT(
                billCount: 0,
                referenceDate: apr1Noon,
                calendar: calendar
            )

            let income = makeMonthlyIncome(
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 4, day: 1),
                in: modelContext
            )
            try modelContext.save()
            try editSUT.refresh() // Apr 1 stays in the future generator (today is today).

            try await editSUT.updateIncome(
                income,
                draft: IncomeDraft(
                    name: income.name,
                    amount: 1_500,
                    startDate: income.startDate,
                    recurrenceRule: income.recurrenceRule
                )
            )

            // Apr 1 row is still not materialized — today's row stays live.
            let rowsOnEditDay = try modelContext.fetch(FetchDescriptor<IncomeOccurrence>())
            #expect(rowsOnEditDay.isEmpty)

            // Advance to Apr 2 and refresh — Apr 1 must materialize at the
            // current (post-edit) amount, not get silently dropped.
            let apr2 = makeDate(year: 2025, month: 4, day: 2)
            let nextDaySUT = BillsModel(
                modelContext: modelContext,
                calendar: calendar,
                currentDate: { apr2 },
                notificationCoordinator: coordinator,
                notificationPreferences: preferences
            )
            try nextDaySUT.refresh()

            let rowsAfter = try modelContext.fetch(FetchDescriptor<IncomeOccurrence>())
            #expect(rowsAfter.count == 1)
            let apr1Row = try #require(rowsAfter.first)
            #expect(calendar.component(.month, from: apr1Row.date) == 4)
            #expect(calendar.component(.day, from: apr1Row.date) == 1)
            #expect(apr1Row.incomeAmount == 1_500)
        }

        @Test func whenIncomeIsDeleted_thenPastOccurrencesArePreservedWithNullIncomeReference() async throws {
            let calendar = utcCalendar()
            let referenceDate = makeDate(year: 2025, month: 4, day: 10)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            let income = makeMonthlyIncome(
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 1, day: 1),
                in: modelContext
            )
            try modelContext.save()

            try await sut.deleteIncome(income)

            let rows = try modelContext.fetch(FetchDescriptor<IncomeOccurrence>())
            #expect(rows.count == 4) // Jan, Feb, Mar, Apr 1 (all strictly before today)
            #expect(rows.allSatisfy { $0.income == nil })
        }

        @Test func whenOccurrenceIsSkipped_thenTotalsExcludeIt() async throws {
            let calendar = utcCalendar()
            // Skip a row in the *current* month so the dashboard's MonthlyTotals
            // window includes (or excludes) it depending on the skip flag.
            let referenceDate = makeDate(year: 2025, month: 4, day: 10)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            _ = makeMonthlyIncome(
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 4, day: 1),
                in: modelContext
            )
            try modelContext.save()
            try sut.refresh()

            #expect(sut.sections.monthlyTotals.incomeTotal == 1_000)

            let rowToSkip = try #require(
                try modelContext.fetch(FetchDescriptor<IncomeOccurrence>())
                    .first { calendar.component(.month, from: $0.date) == 4 }
            )

            try await sut.skipIncomeOccurrence(rowToSkip)

            let viewsAfterSkip = sut.incomeOccurrenceItems(
                rangeStart: makeDate(year: 2025, month: 4, day: 1),
                rangeEnd: makeDate(year: 2025, month: 5, day: 1)
            )
            #expect(viewsAfterSkip.isEmpty)
            #expect(sut.sections.monthlyTotals.incomeTotal == 0)
        }

        @Test func whenSkippedOccurrenceExists_AndRefreshRuns_thenItIsNotResurrected() async throws {
            let calendar = utcCalendar()
            let referenceDate = makeDate(year: 2025, month: 4, day: 10)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            _ = makeMonthlyIncome(
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 1, day: 1),
                in: modelContext
            )
            try modelContext.save()
            try sut.refresh()

            let rowToSkip = try #require(
                try modelContext.fetch(FetchDescriptor<IncomeOccurrence>())
                    .first { calendar.component(.month, from: $0.date) == 2 }
            )
            try await sut.skipIncomeOccurrence(rowToSkip)

            try sut.refresh()
            try sut.refresh()

            let februaryRows = try modelContext
                .fetch(FetchDescriptor<IncomeOccurrence>())
                .filter { calendar.component(.month, from: $0.date) == 2 }
            #expect(februaryRows.count == 1)
            #expect(februaryRows.first?.isExcluded == true)
        }

        @Test func whenTwoPersistedRowsShareOccurrenceKey_thenEarliestCreatedDateWins() async throws {
            let calendar = utcCalendar()
            let referenceDate = makeDate(year: 2025, month: 4, day: 10)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            // Seed the income and *both* January duplicates *before* the first
            // refresh, so the materializer's idempotency check sees an existing
            // row at the January key and adds nothing for it. Refresh runs only
            // once — it caches `incomeOccurrences` for the public method to read.
            let income = makeMonthlyIncome(
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 1, day: 1),
                in: modelContext
            )
            modelContext.insert(income)

            let januaryDate = makeDate(year: 2025, month: 1, day: 1)
            let snapshot = IncomeSnapshot(income: income)
            let key = snapshot.occurrenceKey(for: januaryDate)

            let earlier = makeOccurrence(
                key: key,
                on: januaryDate,
                amount: 1_111,
                createdDate: makeDate(year: 2025, month: 1, day: 1),
                income: income,
                in: modelContext
            )
            let later = makeOccurrence(
                key: key,
                on: januaryDate,
                amount: 9_999,
                createdDate: makeDate(year: 2025, month: 2, day: 1),
                income: income,
                in: modelContext
            )
            _ = (earlier, later)
            try modelContext.save()
            try sut.refresh()

            let januaryViews = sut.incomeOccurrenceItems(
                rangeStart: januaryDate,
                rangeEnd: makeDate(year: 2025, month: 2, day: 1)
            )
            #expect(januaryViews.count == 1)
            #expect(januaryViews.first?.amount == 1_111) // earliest createdDate wins
        }

        @Test func whenOneOfTwoCloudKitDuplicatesIsSkipped_thenNoVisibleRowAtThatKey() async throws {
            let calendar = utcCalendar()
            let referenceDate = makeDate(year: 2025, month: 4, day: 10)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            let income = makeMonthlyIncome(
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 1, day: 1),
                in: modelContext
            )
            try modelContext.save()
            try sut.refresh()

            // Insert a CloudKit-style duplicate of the January row so two rows
            // share the same occurrenceKey.
            let januaryDate = makeDate(year: 2025, month: 1, day: 1)
            let snapshot = IncomeSnapshot(income: income)
            let key = snapshot.occurrenceKey(for: januaryDate)
            let duplicate = IncomeOccurrence(
                occurrenceKey: key,
                date: januaryDate,
                incomeName: income.name,
                incomeAmount: income.amount,
                incomeCurrencyCode: income.currencyCode,
                income: income
            )
            modelContext.insert(duplicate)
            try modelContext.save()
            try sut.refresh()

            let firstRow = try #require(
                try modelContext.fetch(FetchDescriptor<IncomeOccurrence>())
                    .first { $0.occurrenceKey == key }
            )
            try await sut.skipIncomeOccurrence(firstRow)

            let januaryViews = sut.incomeOccurrenceItems(
                rangeStart: januaryDate,
                rangeEnd: makeDate(year: 2025, month: 2, day: 1)
            )
            #expect(januaryViews.isEmpty)
        }

        @Test func whenLateArrivingDuplicateAppearsAfterSkip_thenNoVisibleRowAtThatKey() async throws {
            let calendar = utcCalendar()
            let referenceDate = makeDate(year: 2025, month: 4, day: 10)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            let income = makeMonthlyIncome(
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 1, day: 1),
                in: modelContext
            )
            try modelContext.save()
            try sut.refresh()

            // User skips the January row.
            let januaryDate = makeDate(year: 2025, month: 1, day: 1)
            let skippedRow = try #require(
                try modelContext.fetch(FetchDescriptor<IncomeOccurrence>())
                    .first { calendar.isDate($0.date, inSameDayAs: januaryDate) }
            )
            try await sut.skipIncomeOccurrence(skippedRow)

            // CloudKit later delivers a duplicate for the same key, with an
            // earlier `createdDate` (so it would otherwise win dedupe) and
            // `isExcluded == false`.
            let snapshot = IncomeSnapshot(income: income)
            let key = snapshot.occurrenceKey(for: januaryDate)
            let lateDuplicate = makeOccurrence(
                key: key,
                on: januaryDate,
                amount: 1_000,
                createdDate: skippedRow.createdDate.addingTimeInterval(-3600),
                income: income,
                in: modelContext
            )
            _ = lateDuplicate
            try modelContext.save()
            try sut.refresh()

            let januaryViews = sut.incomeOccurrenceItems(
                rangeStart: januaryDate,
                rangeEnd: makeDate(year: 2025, month: 2, day: 1)
            )
            #expect(januaryViews.isEmpty)
        }

        @Test func whenSkippedOccurrenceExists_andUserEditsSchedule_thenSkipPersists() async throws {
            let calendar = utcCalendar()
            let referenceDate = makeDate(year: 2025, month: 4, day: 10)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            let income = makeMonthlyIncome(
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 1, day: 1),
                in: modelContext
            )
            try modelContext.save()
            try sut.refresh()

            let februaryRow = try #require(
                try modelContext.fetch(FetchDescriptor<IncomeOccurrence>())
                    .first { calendar.component(.month, from: $0.date) == 2 }
            )
            try await sut.skipIncomeOccurrence(februaryRow)

            // User edits schedule to start on the 15th. Past-frozen contract:
            // the existing rows on the 1st must remain (including the skipped
            // February one), and the skipped one must stay hidden.
            try await sut.updateIncome(
                income,
                draft: IncomeDraft(
                    name: income.name,
                    amount: income.amount,
                    startDate: makeDate(year: 2025, month: 1, day: 15),
                    recurrenceRule: income.recurrenceRule
                )
            )

            let februaryViews = sut.incomeOccurrenceItems(
                rangeStart: makeDate(year: 2025, month: 2, day: 1),
                rangeEnd: makeDate(year: 2025, month: 3, day: 1)
            )
            #expect(februaryViews.isEmpty)
        }

        @Test func whenIncomeIsOneTimeAndStartDateIsInThePast_thenSinglePastRowIsMaterialized() async throws {
            let calendar = utcCalendar()
            let referenceDate = makeDate(year: 2025, month: 4, day: 10)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            let oneTimeIncome = Income(
                name: "Bonus",
                amount: 500,
                startDate: makeDate(year: 2025, month: 2, day: 14),
                recurrenceRule: nil
            )
            modelContext.insert(oneTimeIncome)
            try modelContext.save()

            try sut.refresh()

            let rows = try modelContext.fetch(FetchDescriptor<IncomeOccurrence>())
            #expect(rows.count == 1)
            #expect(rows.first?.incomeName == "Bonus")
            #expect(rows.first?.incomeAmount == 500)
        }

        @Test func whenIncomeStartsToday_thenNoPastRowsAreMaterialized() async throws {
            let calendar = utcCalendar()
            let referenceDate = makeDate(year: 2025, month: 4, day: 10)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            _ = makeMonthlyIncome(
                amount: 1_000,
                startDate: referenceDate, // today
                in: modelContext
            )
            try modelContext.save()
            try sut.refresh()

            // Past upper bound is `< startOfDay(today)`; today's row stays in
            // the future generator's output and is not materialized.
            let rows = try modelContext.fetch(FetchDescriptor<IncomeOccurrence>())
            #expect(rows.isEmpty)
        }

        @Test func whenIncomeEndDateEqualsToday_thenIncomeIsTreatedAsActiveForFutureGeneration() async throws {
            let calendar = utcCalendar()
            let referenceDate = makeDate(year: 2025, month: 4, day: 10)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            let income = Income(
                name: "Salary",
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 1, day: 10),
                recurrenceRule: RecurrenceRule(
                    pattern: .monthly,
                    frequency: 1,
                    endConditionType: .endDate,
                    endDate: referenceDate // exactly today
                )
            )
            modelContext.insert(income)
            try modelContext.save()
            try sut.refresh()

            let futureViews = sut.incomeOccurrenceItems(
                rangeStart: referenceDate,
                rangeEnd: makeDate(year: 2025, month: 5, day: 1)
            )
            // Income is "active on/before today" so today's projection counts.
            #expect(futureViews.contains { calendar.isDate($0.date, inSameDayAs: referenceDate) })
        }

        @Test func whenSkipIsCalledOnAlreadyExcludedRow_thenExcludedDateIsPreserved() async throws {
            let calendar = utcCalendar()
            let referenceDate = makeDate(year: 2025, month: 4, day: 10)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            _ = makeMonthlyIncome(
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 1, day: 1),
                in: modelContext
            )
            try modelContext.save()
            try sut.refresh()

            let februaryRow = try #require(
                try modelContext.fetch(FetchDescriptor<IncomeOccurrence>())
                    .first { calendar.component(.month, from: $0.date) == 2 }
            )

            try await sut.skipIncomeOccurrence(februaryRow)
            let firstExcludedDate = try #require(februaryRow.excludedDate)

            try await sut.skipIncomeOccurrence(februaryRow)

            // Skip is a no-op when the row is already excluded — the timestamp
            // stays at the original exclusion moment.
            #expect(februaryRow.excludedDate == firstExcludedDate)
        }

        @Test func whenCallerPassesReferenceDate_thenItIsUsedAsPastFutureBoundary() async throws {
            let calendar = utcCalendar()
            let modelClock = makeDate(year: 2025, month: 4, day: 10)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: modelClock,
                calendar: calendar
            )

            _ = makeMonthlyIncome(
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 1, day: 1),
                in: modelContext
            )
            try modelContext.save()
            try sut.refresh()

            // Caller explicitly pins the boundary at March 1 — *before* the
            // model's clock. Anything on or after March 1 should be treated as
            // future and computed; anything strictly before should come from
            // persisted history.
            let callerBoundary = makeDate(year: 2025, month: 3, day: 1)
            let viewsWithCallerClock = sut.incomeOccurrenceItems(
                rangeStart: makeDate(year: 2025, month: 1, day: 1),
                rangeEnd: makeDate(year: 2025, month: 5, day: 1),
                referenceDate: callerBoundary
            )

            // Persisted past-with-respect-to-March-1: Jan, Feb 1 → 2 rows.
            // Future-with-respect-to-March-1: Mar 1, Apr 1 → 2 computed rows.
            // (Apr 15 of the post-edit schedule is NOT here because we never
            //  edited; this test exercises the boundary, not schedule editing.)
            let persistedRows = viewsWithCallerClock.filter(\.isPersisted)
            let computedRows = viewsWithCallerClock.filter { !$0.isPersisted }
            #expect(persistedRows.count == 2)
            #expect(computedRows.count == 2)
        }

        @Test func whenIncomeHasEndedBeforeToday_thenNoFutureRowsAreGenerated() async throws {
            let calendar = utcCalendar()
            let referenceDate = makeDate(year: 2025, month: 4, day: 10)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            let income = Income(
                name: "Old salary",
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 1, day: 1),
                recurrenceRule: RecurrenceRule(
                    pattern: .monthly,
                    frequency: 1,
                    endConditionType: .endDate,
                    endDate: makeDate(year: 2025, month: 2, day: 1)
                )
            )
            modelContext.insert(income)
            try modelContext.save()
            try sut.refresh()

            let futureViews = sut.incomeOccurrenceItems(
                rangeStart: referenceDate,
                rangeEnd: makeDate(year: 2025, month: 7, day: 1)
            )
            #expect(futureViews.isEmpty)
        }
    }

    @MainActor
    @Suite("income occurrence per-row mutations")
    struct IncomeOccurrencePerRowMutations {
        @Test func whenSingleOccurrenceAmountIsEdited_thenOnlyThatRowChanges() async throws {
            let calendar = utcCalendar()
            let referenceDate = makeDate(year: 2025, month: 4, day: 10)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            _ = makeMonthlyIncome(
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 1, day: 1),
                in: modelContext
            )
            try modelContext.save()
            try sut.refresh()

            let februaryRow = try #require(
                try modelContext.fetch(FetchDescriptor<IncomeOccurrence>())
                    .first { calendar.component(.month, from: $0.date) == 2 }
            )

            try await sut.editIncomeOccurrenceAmount(februaryRow, amount: 1_337)

            let allRows = try modelContext.fetch(FetchDescriptor<IncomeOccurrence>())
                .sorted { $0.date < $1.date }
            let months = allRows.map { calendar.component(.month, from: $0.date) }
            let amounts = allRows.map(\.incomeAmount)
            #expect(months == [1, 2, 3, 4])
            #expect(amounts == [1_000, 1_337, 1_000, 1_000])
        }

        @Test func whenAmountEditUsesNonPositiveValue_thenThrowsNonPositiveAmountAndRowIsUnchanged() async throws {
            let calendar = utcCalendar()
            let referenceDate = makeDate(year: 2025, month: 4, day: 10)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            _ = makeMonthlyIncome(
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 1, day: 1),
                in: modelContext
            )
            try modelContext.save()
            try sut.refresh()

            let row = try #require(
                try modelContext.fetch(FetchDescriptor<IncomeOccurrence>())
                    .first { calendar.component(.month, from: $0.date) == 2 }
            )

            await #expect(throws: IncomeValidationError.nonPositiveAmount) {
                try await sut.editIncomeOccurrenceAmount(row, amount: 0)
            }

            #expect(row.incomeAmount == 1_000) // unchanged
        }

        @Test func whenSingleOccurrenceIsDeleted_thenItStaysHiddenAfterRefresh() async throws {
            // The "delete this occurrence" affordance must survive subsequent
            // refreshes — a hard delete would let the materializer recreate
            // the row at the same key. Soft-skip is what makes the deletion
            // stick.
            let calendar = utcCalendar()
            let referenceDate = makeDate(year: 2025, month: 4, day: 10)
            let (sut, _, modelContext, _, _) = try makeSUT(
                billCount: 0,
                referenceDate: referenceDate,
                calendar: calendar
            )

            _ = makeMonthlyIncome(
                amount: 1_000,
                startDate: makeDate(year: 2025, month: 1, day: 1),
                in: modelContext
            )
            try modelContext.save()
            try sut.refresh()

            let februaryRow = try #require(
                try modelContext.fetch(FetchDescriptor<IncomeOccurrence>())
                    .first { calendar.component(.month, from: $0.date) == 2 }
            )

            try await sut.deleteIncomeOccurrence(februaryRow)
            try sut.refresh()
            try sut.refresh()

            let februaryRowsAfter = try modelContext
                .fetch(FetchDescriptor<IncomeOccurrence>())
                .filter { calendar.component(.month, from: $0.date) == 2 }
            #expect(februaryRowsAfter.count == 1)
            #expect(februaryRowsAfter.first?.isExcluded == true)

            // And the dashboard's view-layer filter hides it.
            let februaryViews = sut.incomeOccurrenceItems(
                rangeStart: makeDate(year: 2025, month: 2, day: 1),
                rangeEnd: makeDate(year: 2025, month: 3, day: 1)
            )
            #expect(februaryViews.isEmpty)
        }
    }

    @MainActor
    @Suite("updateIncome validation")
    struct UpdateIncomeValidation {
        @Test func whenDraftHasEmptyName_thenThrowsEmptyNameAndIncomeIsUnchanged() async throws {
            let (sut, income, modelContext) = try makeIncomeSUT()

            await #expect(throws: IncomeValidationError.emptyName) {
                try await sut.updateIncome(
                    income,
                    draft: makeDraft(from: income, name: "")
                )
            }

            // Mutation must not have leaked through.
            #expect(income.name == "Salary")
            let persisted = try modelContext.fetch(FetchDescriptor<Income>())
            #expect(persisted.first?.name == "Salary")
        }

        @Test func whenDraftHasWhitespaceOnlyName_thenThrowsEmptyName() async throws {
            let (sut, income, _) = try makeIncomeSUT()

            await #expect(throws: IncomeValidationError.emptyName) {
                try await sut.updateIncome(
                    income,
                    draft: makeDraft(from: income, name: "   ")
                )
            }
        }

        @Test func whenDraftHasNonPositiveAmount_thenThrowsNonPositiveAmount() async throws {
            let (sut, income, _) = try makeIncomeSUT()

            await #expect(throws: IncomeValidationError.nonPositiveAmount) {
                try await sut.updateIncome(
                    income,
                    draft: makeDraft(from: income, amount: 0)
                )
            }

            await #expect(throws: IncomeValidationError.nonPositiveAmount) {
                try await sut.updateIncome(
                    income,
                    draft: makeDraft(from: income, amount: -50)
                )
            }
        }

        @Test func whenDraftRecurrenceEndDateIsBeforeStartDate_thenThrowsEndDateBeforeStartDate() async throws {
            let (sut, income, _) = try makeIncomeSUT()

            let endBeforeStartRule = RecurrenceRule(
                pattern: .monthly,
                frequency: 1,
                endConditionType: .endDate,
                endDate: makeDate(year: 2024, month: 12, day: 1)
            )

            await #expect(throws: IncomeValidationError.endDateBeforeStartDate) {
                try await sut.updateIncome(
                    income,
                    draft: makeDraft(
                        from: income,
                        startDate: makeDate(year: 2025, month: 1, day: 1),
                        recurrenceRule: endBeforeStartRule
                    )
                )
            }
        }

        @Test func whenDraftHasUntrimmedName_thenPersistsTrimmedName() async throws {
            let (sut, income, _) = try makeIncomeSUT()

            try await sut.updateIncome(
                income,
                draft: makeDraft(from: income, name: "  Monthly Salary  ")
            )

            #expect(income.name == "Monthly Salary")
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
    }(),
    analyticsCapture: @escaping (AnalyticsEvent) -> Void = { _ in }
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
        Income.self,
        IncomeOccurrence.self,
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
        notificationPreferences: preferences,
        analyticsCapture: analyticsCapture
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

/// Wall-clock helper for tests that need a non-midnight `currentDate()` —
/// used by Finding-1 regression tests where the bug only surfaces when the
/// stored boundary is a precise timestamp instead of a normalized day.
private func makeDateTime(year: Int = 2025, month: Int = 1, day: Int, hour: Int, minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.locale = Locale(identifier: "en_US")
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return calendar.date(from: components)!
}

@MainActor
private func makeOccurrence(for bill: Bill, dueDate: Date? = nil) -> BillOccurrence {
    BillOccurrence(bill: bill, dueDate: dueDate ?? bill.dueDate)
}

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.locale = Locale(identifier: "en_US")
    return calendar
}

@MainActor
@discardableResult
private func makeMonthlyIncome(
    name: String = "Salary",
    amount: Decimal,
    startDate: Date,
    in context: ModelContext
) -> Income {
    let income = Income(
        name: name,
        amount: amount,
        startDate: startDate,
        recurrenceRule: RecurrenceRule(pattern: .monthly, frequency: 1)
    )
    context.insert(income)
    return income
}

@MainActor
@discardableResult
private func makeOccurrence(
    key: String,
    on date: Date,
    amount: Decimal,
    createdDate: Date? = nil,
    income: Income,
    in context: ModelContext
) -> IncomeOccurrence {
    let row = IncomeOccurrence(
        occurrenceKey: key,
        date: date,
        incomeName: income.name,
        incomeAmount: amount,
        incomeCurrencyCode: income.currencyCode,
        income: income
    )
    if let createdDate {
        row.createdDate = createdDate
    }
    context.insert(row)
    return row
}

/// SUT specialized for `UpdateIncomeValidation` tests: ships with one valid
/// monthly income preinserted so each test only has to express the *invalid*
/// draft it wants to push through `updateIncome`. Refresh has not run, so
/// nothing is materialized yet — the failing path under test must not depend
/// on prior steady-state behavior.
@MainActor
private func makeIncomeSUT() throws -> (BillsModel, Income, ModelContext) {
    let referenceDate = makeDate(year: 2025, month: 4, day: 10)
    let (sut, _, modelContext, _, _) = try makeSUT(
        billCount: 0,
        referenceDate: referenceDate,
        calendar: utcCalendar()
    )
    let income = makeMonthlyIncome(
        name: "Salary",
        amount: 1_000,
        startDate: makeDate(year: 2025, month: 1, day: 1),
        in: modelContext
    )
    try modelContext.save()
    return (sut, income, modelContext)
}

/// Build an `IncomeDraft` from an existing income, overriding only the fields
/// the test wants to vary. Lets a test body read like the business scenario
/// (`makeDraft(from: income, amount: 0)`) instead of the field-by-field
/// boilerplate.
@MainActor
private func makeDraft(
    from income: Income,
    name: String? = nil,
    amount: Decimal? = nil,
    startDate: Date? = nil,
    recurrenceRule: RecurrenceRule? = nil
) -> IncomeDraft {
    IncomeDraft(
        name: name ?? income.name,
        amount: amount ?? income.amount,
        startDate: startDate ?? income.startDate,
        recurrenceRule: recurrenceRule ?? income.recurrenceRule
    )
}

// MARK: - Test Doubles
