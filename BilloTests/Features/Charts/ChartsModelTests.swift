//  Created by Jiri Urbasek on 01/21/26.

import Testing
import SwiftData
import Foundation
@testable import Billo

@Suite("ChartsModel")
@MainActor
struct ChartsModelTests {

    // MARK: - hasData

    @Suite("hasData")
    @MainActor
    struct HasData {
        @Test func whenNoBills_thenHasDataIsFalse() throws {
            let (sut, _) = try makeSUT()

            sut.refresh()

            #expect(sut.state?.hasData == false)
        }

        @Test func whenBillsExist_thenHasDataIsTrue() throws {
            let (sut, context) = try makeSUT()
            let bill = makeBill(name: "Rent", amount: 1500)
            context.insert(bill)

            sut.refresh()

            #expect(sut.state?.hasData == true)
        }

        @Test func whenOnlyIncomeExists_thenHasDataIsTrue() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)
            let income = makeIncome(name: "Salary", amount: 5000, startDate: makeDate(year: 2026, month: 1, day: 1))
            context.insert(income)

            sut.refresh()

            #expect(sut.state?.hasData == true)
        }

        @Test func whenOnlyOrphanedPaymentHistoryExists_thenHasDataIsTrue() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(name: "Old Gym", amount: 30, dueDate: makeDate(year: 2026, month: 2, day: 10))
            context.insert(bill)
            recordPayment(for: bill, occurrenceDueDate: bill.dueDate, datePaid: makeDate(year: 2026, month: 2, day: 10), in: context)
            context.delete(bill)
            try context.save()

            sut.refresh()

            #expect(sut.state?.hasData == true)
        }
    }

    // MARK: - Monthly Cash Flow

    @Suite("monthlyCashFlow")
    @MainActor
    struct MonthlyCashFlow {
        @Test func whenNoBillsOrIncomes_thenCashFlowIsZero() throws {
            let (sut, _) = try makeSUT(
                currentDate: makeDate(year: 2026, month: 1, day: 15)
            )

            sut.refresh()

            let cashFlow = try #require(sut.state?.cashFlow)
            #expect(cashFlow.income == 0)
            #expect(cashFlow.bills == 0)
            #expect(cashFlow.net == 0)
        }

        @Test func whenUnpaidBillsInCurrentMonth_thenBillsTotalIsOutstanding() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill1 = makeBill(name: "Rent", amount: 1500, dueDate: makeDate(year: 2026, month: 1, day: 1))
            let bill2 = makeBill(name: "Utilities", amount: 200, dueDate: makeDate(year: 2026, month: 1, day: 10))
            context.insert(bill1)
            context.insert(bill2)

            sut.refresh()

            let cashFlow = try #require(sut.state?.cashFlow)
            #expect(cashFlow.bills == 1700)
            #expect(cashFlow.billsOutstanding == 1700)
            #expect(cashFlow.billsPaid == 0)
        }

        @Test func whenIncomeInCurrentMonth_thenIncomeTotalCalculated() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let income = makeIncome(name: "Salary", amount: 5000, startDate: makeDate(year: 2026, month: 1, day: 1))
            context.insert(income)

            sut.refresh()

            let cashFlow = try #require(sut.state?.cashFlow)
            #expect(cashFlow.income == 5000)
        }

        @Test func whenIncomeExceedsBills_thenNetIsPositive() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(name: "Rent", amount: 1500, dueDate: makeDate(year: 2026, month: 1, day: 1))
            let income = makeIncome(name: "Salary", amount: 5000, startDate: makeDate(year: 2026, month: 1, day: 1))
            context.insert(bill)
            context.insert(income)

            sut.refresh()

            let cashFlow = try #require(sut.state?.cashFlow)
            #expect(cashFlow.net == 3500)
        }

        @Test func whenBillsExceedIncome_thenNetIsNegative() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(name: "Rent", amount: 3000, dueDate: makeDate(year: 2026, month: 1, day: 1))
            let income = makeIncome(name: "Salary", amount: 2000, startDate: makeDate(year: 2026, month: 1, day: 1))
            context.insert(bill)
            context.insert(income)

            sut.refresh()

            let cashFlow = try #require(sut.state?.cashFlow)
            #expect(cashFlow.net == -1000)
        }

        @Test func whenBillsDueOutsideMonth_thenNotIncluded() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(name: "Future Bill", amount: 500, dueDate: makeDate(year: 2026, month: 2, day: 15))
            context.insert(bill)

            sut.refresh()

            let cashFlow = try #require(sut.state?.cashFlow)
            #expect(cashFlow.bills == 0)
        }

        @Test func whenMonthLabelGenerated_thenFormattedCorrectly() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, _) = try makeSUT(currentDate: referenceDate)

            sut.refresh()

            let cashFlow = try #require(sut.state?.cashFlow)
            #expect(cashFlow.monthLabel.contains("2026"))
        }
    }

    // MARK: - Actual Payments

    @Suite("actualPayments")
    @MainActor
    struct ActualPayments {
        @Test func whenPastBillPaidMoreThanScheduled_thenCashFlowShowsActualPaidAmount() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let electricBill = makeBill(name: "Electric", amount: 100, dueDate: makeDate(year: 2026, month: 2, day: 10))
            context.insert(electricBill)
            recordPayment(
                for: electricBill,
                occurrenceDueDate: electricBill.dueDate,
                amount: 120,
                datePaid: makeDate(year: 2026, month: 2, day: 11),
                in: context
            )

            sut.refresh()
            sut.stepMonth(by: -1)

            let cashFlow = try #require(sut.state?.cashFlow)
            #expect(cashFlow.billsPaid == 120)
            #expect(cashFlow.billsOutstanding == 0)
        }

        @Test func whenPastBillPartiallyPaid_thenCashFlowSplitsPaidAndOutstanding() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let electricBill = makeBill(name: "Electric", amount: 100, dueDate: makeDate(year: 2026, month: 2, day: 10))
            context.insert(electricBill)
            recordPayment(
                for: electricBill,
                occurrenceDueDate: electricBill.dueDate,
                amount: 80,
                datePaid: makeDate(year: 2026, month: 2, day: 11),
                in: context
            )

            sut.refresh()
            sut.stepMonth(by: -1)

            let cashFlow = try #require(sut.state?.cashFlow)
            #expect(cashFlow.billsPaid == 80)
            #expect(cashFlow.billsOutstanding == 20)
            #expect(cashFlow.bills == 100)
        }

        @Test func whenPastBillUnpaid_thenCashFlowShowsFullOutstandingAmount() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let missedBill = makeBill(name: "Missed", amount: 250, dueDate: makeDate(year: 2026, month: 2, day: 20))
            context.insert(missedBill)

            sut.refresh()
            sut.stepMonth(by: -1)

            let cashFlow = try #require(sut.state?.cashFlow)
            #expect(cashFlow.billsPaid == 0)
            #expect(cashFlow.billsOutstanding == 250)
        }

        @Test func whenBillPaidInDifferentMonthThanDue_thenPaymentCountsInMonthOfPayment() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let lateBill = makeBill(name: "Paid Late", amount: 300, dueDate: makeDate(year: 2026, month: 1, day: 28))
            context.insert(lateBill)
            recordPayment(
                for: lateBill,
                occurrenceDueDate: lateBill.dueDate,
                datePaid: makeDate(year: 2026, month: 2, day: 3),
                in: context
            )

            sut.refresh()

            sut.stepMonth(by: -2) // January: due here, but fully paid → nothing outstanding, nothing paid
            let january = try #require(sut.state?.cashFlow)
            #expect(january.billsPaid == 0)
            #expect(january.billsOutstanding == 0)

            sut.stepMonth(by: 1) // February: payment actually happened here
            let february = try #require(sut.state?.cashFlow)
            #expect(february.billsPaid == 300)
            #expect(february.billsOutstanding == 0)
        }

        @Test func whenBillDeletedAfterPayment_thenPastMonthStillShowsPayment() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let deletedBill = makeBill(
                name: "Cancelled Gym",
                amount: 45,
                dueDate: makeDate(year: 2026, month: 2, day: 5),
                category: .predefined(.subscriptions)
            )
            context.insert(deletedBill)
            recordPayment(
                for: deletedBill,
                occurrenceDueDate: deletedBill.dueDate,
                datePaid: makeDate(year: 2026, month: 2, day: 5),
                in: context
            )
            context.delete(deletedBill)
            try context.save()

            sut.refresh()
            sut.stepMonth(by: -1)

            let cashFlow = try #require(sut.state?.cashFlow)
            #expect(cashFlow.billsPaid == 45)

            let breakdown = try #require(sut.state?.categoryBreakdown)
            #expect(breakdown.slices.map(\.category) == [.predefined(.subscriptions)])
        }

        @Test func whenPaymentHasNoOccurrenceSnapshot_thenCountedAsOtherCategory() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let orphanPayment = PaymentEntry(
                amount: 60,
                datePaid: makeDate(year: 2026, month: 2, day: 8)
            )
            context.insert(orphanPayment)

            sut.refresh()
            sut.stepMonth(by: -1)

            let cashFlow = try #require(sut.state?.cashFlow)
            #expect(cashFlow.billsPaid == 60)

            let breakdown = try #require(sut.state?.categoryBreakdown)
            #expect(breakdown.slices.map(\.category) == [.predefined(.other)])
        }

        @Test func whenPastMonthSelected_thenBreakdownReflectsActualPaymentsByCategory() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let rent = makeBill(
                name: "Rent",
                amount: 1500,
                dueDate: makeDate(year: 2026, month: 2, day: 1),
                category: .predefined(.housing)
            )
            let internet = makeBill(
                name: "Internet",
                amount: 80,
                dueDate: makeDate(year: 2026, month: 2, day: 5),
                category: .predefined(.utilities)
            )
            context.insert(rent)
            context.insert(internet)
            recordPayment(for: rent, occurrenceDueDate: rent.dueDate, datePaid: makeDate(year: 2026, month: 2, day: 1), in: context)
            recordPayment(for: internet, occurrenceDueDate: internet.dueDate, amount: 75, datePaid: makeDate(year: 2026, month: 2, day: 6), in: context)

            sut.refresh()
            sut.stepMonth(by: -1)

            // Utilities slice = 75 actually paid + 5 still owed on the
            // partially paid occurrence, matching the calendar's semantics.
            let breakdown = try #require(sut.state?.categoryBreakdown)
            #expect(breakdown.total == 1580)
            #expect(breakdown.slices.map(\.category) == [.predefined(.housing), .predefined(.utilities)])
            #expect(breakdown.slices.map(\.amount) == [1500, 80])
        }
    }

    // MARK: - Selected Month

    @Suite("selectedMonth")
    @MainActor
    struct SelectedMonth {
        @Test func whenInitialized_thenViewingCurrentMonth() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, _) = try makeSUT(currentDate: referenceDate)

            sut.refresh()

            #expect(sut.isViewingCurrentMonth == true)
        }

        @Test func whenSteppingBackOneMonth_thenCashFlowReflectsPreviousMonth() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let februaryBill = makeBill(name: "Feb Only", amount: 400, dueDate: makeDate(year: 2026, month: 2, day: 10))
            context.insert(februaryBill)

            sut.refresh()
            sut.stepMonth(by: -1)

            let cashFlow = try #require(sut.state?.cashFlow)
            #expect(cashFlow.bills == 400)
            #expect(sut.isViewingCurrentMonth == false)
        }

        @Test func whenSteppingForward_thenShowsFutureScheduledBills() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let aprilBill = makeBill(name: "April Only", amount: 900, dueDate: makeDate(year: 2026, month: 4, day: 10))
            context.insert(aprilBill)

            sut.refresh()
            sut.stepMonth(by: 1)

            let cashFlow = try #require(sut.state?.cashFlow)
            #expect(cashFlow.billsOutstanding == 900)
            #expect(cashFlow.billsPaid == 0)
        }

        @Test func whenResettingToCurrentMonth_thenViewingCurrentMonthAgain() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let marchBill = makeBill(name: "March", amount: 100, dueDate: makeDate(year: 2026, month: 3, day: 20))
            context.insert(marchBill)

            sut.refresh()
            sut.stepMonth(by: -2)
            sut.resetToCurrentMonth()

            let cashFlow = try #require(sut.state?.cashFlow)
            #expect(sut.isViewingCurrentMonth == true)
            #expect(cashFlow.bills == 100)
        }

        @Test func whenSteppingToEmptyMonth_thenHasDataStaysTrue() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(name: "March Bill", amount: 100, dueDate: makeDate(year: 2026, month: 3, day: 20))
            context.insert(bill)

            sut.refresh()
            sut.stepMonth(by: -3) // December 2025: nothing there

            #expect(sut.state?.hasData == true)
            #expect(sut.state?.cashFlow.bills == 0)
        }

        @Test func whenSteppingMonths_thenTrendChartsStayAnchoredToToday() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(
                name: "Rent",
                amount: 1500,
                dueDate: makeDate(year: 2026, month: 1, day: 1),
                recurrenceRule: RecurrenceRule(pattern: .monthly, frequency: 1)
            )
            context.insert(bill)

            sut.refresh()
            let trendBeforeStepping = try #require(sut.state?.monthlyTrend)

            sut.stepMonth(by: -2)
            let trendAfterStepping = try #require(sut.state?.monthlyTrend)

            #expect(trendBeforeStepping == trendAfterStepping)
        }
    }

    // MARK: - Income Snapshots

    @Suite("incomeSnapshots")
    @MainActor
    struct IncomeSnapshots {
        @Test func whenPastIncomeOccurrenceHasEditedAmount_thenIncomeUsesSnapshotAmount() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let income = makeIncome(name: "Salary", amount: 5000, startDate: makeDate(year: 2026, month: 1, day: 1))
            context.insert(income)
            context.insert(makeIncomeOccurrence(for: income, date: makeDate(year: 2026, month: 1, day: 1), amount: 3000))

            sut.refresh()

            let cashFlow = try #require(sut.state?.cashFlow)
            #expect(cashFlow.income == 3000)
        }

        @Test func whenIncomeOccurrenceExcluded_thenNotCountedInIncome() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let income = makeIncome(name: "Salary", amount: 5000, startDate: makeDate(year: 2026, month: 1, day: 1))
            context.insert(income)
            context.insert(makeIncomeOccurrence(for: income, date: makeDate(year: 2026, month: 1, day: 1), amount: 5000, isExcluded: true))

            sut.refresh()

            let cashFlow = try #require(sut.state?.cashFlow)
            #expect(cashFlow.income == 0)
        }

        @Test func whenIncomeDeletedButOccurrenceRowsRemain_thenPastIncomeStillCounted() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            context.insert(makeIncomeOccurrence(for: nil, date: makeDate(year: 2026, month: 2, day: 1), amount: 850))

            sut.refresh()
            sut.stepMonth(by: -1)

            let cashFlow = try #require(sut.state?.cashFlow)
            #expect(cashFlow.income == 850)
        }
    }

    // MARK: - Payment Timing

    @Suite("paymentTiming")
    @MainActor
    struct PaymentTiming {
        @Test func whenPaymentOnDueDate_thenCountedOnTime() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(name: "Rent", amount: 1500, dueDate: makeDate(year: 2026, month: 2, day: 10))
            context.insert(bill)
            recordPayment(for: bill, occurrenceDueDate: bill.dueDate, datePaid: makeDate(year: 2026, month: 2, day: 10), in: context)

            sut.refresh()

            let timing = try #require(sut.state?.paymentTiming)
            #expect(timing.onTimePercentage == 100)
            #expect(totalCounts(of: timing) == (onTime: 1, late: 0))
        }

        @Test func whenPaymentBeforeDueDate_thenCountedOnTime() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(name: "Rent", amount: 1500, dueDate: makeDate(year: 2026, month: 2, day: 10))
            context.insert(bill)
            recordPayment(for: bill, occurrenceDueDate: bill.dueDate, datePaid: makeDate(year: 2026, month: 2, day: 7), in: context)

            sut.refresh()

            let timing = try #require(sut.state?.paymentTiming)
            #expect(totalCounts(of: timing) == (onTime: 1, late: 0))
        }

        @Test func whenPaymentAfterDueDate_thenCountedLate() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(name: "Rent", amount: 1500, dueDate: makeDate(year: 2026, month: 2, day: 10))
            context.insert(bill)
            recordPayment(for: bill, occurrenceDueDate: bill.dueDate, datePaid: makeDate(year: 2026, month: 2, day: 13), in: context)

            sut.refresh()

            let timing = try #require(sut.state?.paymentTiming)
            #expect(timing.onTimePercentage == 0)
            #expect(totalCounts(of: timing) == (onTime: 0, late: 1))
        }

        @Test func whenMixedPayments_thenOnTimePercentageCalculated() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(
                name: "Rent",
                amount: 1500,
                dueDate: makeDate(year: 2025, month: 11, day: 10),
                recurrenceRule: RecurrenceRule(pattern: .monthly, frequency: 1)
            )
            context.insert(bill)
            // 3 on-time, 1 late
            recordPayment(for: bill, occurrenceDueDate: makeDate(year: 2025, month: 11, day: 10), datePaid: makeDate(year: 2025, month: 11, day: 9), in: context)
            recordPayment(for: bill, occurrenceDueDate: makeDate(year: 2025, month: 12, day: 10), datePaid: makeDate(year: 2025, month: 12, day: 10), in: context)
            recordPayment(for: bill, occurrenceDueDate: makeDate(year: 2026, month: 1, day: 10), datePaid: makeDate(year: 2026, month: 1, day: 8), in: context)
            recordPayment(for: bill, occurrenceDueDate: makeDate(year: 2026, month: 2, day: 10), datePaid: makeDate(year: 2026, month: 2, day: 15), in: context)

            sut.refresh()

            let timing = try #require(sut.state?.paymentTiming)
            #expect(timing.onTimePercentage == 75)
            #expect(totalCounts(of: timing) == (onTime: 3, late: 1))
        }

        @Test func whenPaymentsLateByTwoAndFourDays_thenAverageDaysLateIsThree() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(
                name: "Rent",
                amount: 1500,
                dueDate: makeDate(year: 2026, month: 1, day: 10),
                recurrenceRule: RecurrenceRule(pattern: .monthly, frequency: 1)
            )
            context.insert(bill)
            recordPayment(for: bill, occurrenceDueDate: makeDate(year: 2026, month: 1, day: 10), datePaid: makeDate(year: 2026, month: 1, day: 12), in: context)
            recordPayment(for: bill, occurrenceDueDate: makeDate(year: 2026, month: 2, day: 10), datePaid: makeDate(year: 2026, month: 2, day: 14), in: context)

            sut.refresh()

            let timing = try #require(sut.state?.paymentTiming)
            #expect(timing.averageDaysLate == 3)
        }

        @Test func whenPaymentLacksOccurrenceSnapshot_thenExcludedFromTiming() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let orphanPayment = PaymentEntry(
                amount: 60,
                datePaid: makeDate(year: 2026, month: 2, day: 8)
            )
            context.insert(orphanPayment)

            sut.refresh()

            let timing = try #require(sut.state?.paymentTiming)
            #expect(timing.onTimePercentage == nil)
            #expect(totalCounts(of: timing) == (onTime: 0, late: 0))
        }

        @Test func whenNoPayments_thenTimingHasNoPercentage() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, _) = try makeSUT(currentDate: referenceDate)

            sut.refresh()

            let timing = try #require(sut.state?.paymentTiming)
            #expect(timing.onTimePercentage == nil)
            #expect(timing.averageDaysLate == nil)
        }

        @Test func whenLatePaymentCrossesMonthBoundary_thenCountedInMonthOfPayment() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(name: "Rent", amount: 1500, dueDate: makeDate(year: 2026, month: 1, day: 28))
            context.insert(bill)
            recordPayment(for: bill, occurrenceDueDate: bill.dueDate, datePaid: makeDate(year: 2026, month: 2, day: 2), in: context)

            sut.refresh()

            let timing = try #require(sut.state?.paymentTiming)
            let februaryPoint = try #require(timing.points.first { $0.monthLabel.hasPrefix("Feb") })
            let januaryPoint = try #require(timing.points.first { $0.monthLabel.hasPrefix("Jan") })
            #expect(februaryPoint.lateCount == 1)
            #expect(januaryPoint.lateCount == 0)
        }

        @Test func whenPaymentOlderThanTrendWindow_thenExcludedFromTiming() throws {
            let referenceDate = makeDate(year: 2026, month: 8, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(name: "Old Bill", amount: 100, dueDate: makeDate(year: 2026, month: 1, day: 10))
            context.insert(bill)
            recordPayment(for: bill, occurrenceDueDate: bill.dueDate, datePaid: makeDate(year: 2026, month: 1, day: 10), in: context)

            sut.refresh()

            let timing = try #require(sut.state?.paymentTiming)
            #expect(timing.onTimePercentage == nil)
            #expect(timing.points.count == 6)
        }
    }

    // MARK: - Category Breakdown

    @Suite("categoryBreakdown")
    @MainActor
    struct CategoryBreakdown {
        @Test func whenNoBills_thenBreakdownIsEmpty() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, _) = try makeSUT(currentDate: referenceDate)

            sut.refresh()

            let breakdown = try #require(sut.state?.categoryBreakdown)
            #expect(breakdown.slices.isEmpty)
            #expect(breakdown.total == 0)
        }

        @Test func whenSingleCategory_thenSliceHas100Percent() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(
                name: "Rent",
                amount: 1500,
                dueDate: makeDate(year: 2026, month: 1, day: 1),
                category: .predefined(.housing)
            )
            context.insert(bill)

            sut.refresh()

            let breakdown = try #require(sut.state?.categoryBreakdown)
            #expect(breakdown.slices.count == 1)
            #expect(breakdown.slices[0].category == .predefined(.housing))
            #expect(breakdown.slices[0].percentage == 100)
            #expect(breakdown.total == 1500)
        }

        @Test func whenMultipleCategories_thenPercentagesCalculated() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill1 = makeBill(
                name: "Rent",
                amount: 750,
                dueDate: makeDate(year: 2026, month: 1, day: 1),
                category: .predefined(.housing)
            )
            let bill2 = makeBill(
                name: "Utilities",
                amount: 250,
                dueDate: makeDate(year: 2026, month: 1, day: 5),
                category: .predefined(.utilities)
            )
            context.insert(bill1)
            context.insert(bill2)

            sut.refresh()

            let breakdown = try #require(sut.state?.categoryBreakdown)
            #expect(breakdown.slices.count == 2)
            #expect(breakdown.total == 1000)

            // Sorted by amount descending
            #expect(breakdown.slices[0].category == .predefined(.housing))
            #expect(breakdown.slices[0].percentage == 75)
            #expect(breakdown.slices[1].category == .predefined(.utilities))
            #expect(breakdown.slices[1].percentage == 25)
        }

        @Test func whenBillHasNoCategory_thenGroupedAsOther() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(
                name: "Random Bill",
                amount: 100,
                dueDate: makeDate(year: 2026, month: 1, day: 1),
                category: nil
            )
            context.insert(bill)

            sut.refresh()

            let breakdown = try #require(sut.state?.categoryBreakdown)
            #expect(breakdown.slices.count == 1)
            #expect(breakdown.slices[0].category == .predefined(.other))
        }

        @Test func whenCustomCategoryUsed_thenSliceUsesItsNameIconAndColor() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            context.insert(makeCustomCategory(id: "Pets", name: "Pets", iconToken: "pawprint.fill", colorHex: "#00C7BE"))
            let bill = makeBill(
                name: "Pet Food",
                amount: 150,
                dueDate: makeDate(year: 2026, month: 1, day: 1),
                category: .custom("Pets")
            )
            context.insert(bill)

            sut.refresh()

            let breakdown = try #require(sut.state?.categoryBreakdown)
            #expect(breakdown.slices.count == 1)
            #expect(breakdown.slices[0].category == .custom("Pets"))
            #expect(breakdown.slices[0].display.name == "Pets")
            #expect(breakdown.slices[0].display.systemImageName == "pawprint.fill")
            #expect(breakdown.slices[0].display.colorHex == "#00C7BE")
        }

        @Test func whenReferencedCustomCategoryDeleted_thenSpendingFoldsIntoOtherSlice() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(
                name: "Orphaned Bill",
                amount: 150,
                dueDate: makeDate(year: 2026, month: 1, day: 1),
                category: .custom("deleted-category-id")
            )
            context.insert(bill)

            sut.refresh()

            let breakdown = try #require(sut.state?.categoryBreakdown)
            #expect(breakdown.slices.count == 1)
            #expect(breakdown.slices[0].category == .predefined(.other))
            #expect(breakdown.total == 150)
        }

        @Test func whenZeroAmountBill_thenNotIncludedInBreakdown() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let zeroBill = makeBill(
                name: "Free Trial",
                amount: 0,
                dueDate: makeDate(year: 2026, month: 1, day: 1),
                category: .predefined(.subscriptions)
            )
            let regularBill = makeBill(
                name: "Netflix",
                amount: 15,
                dueDate: makeDate(year: 2026, month: 1, day: 5),
                category: .predefined(.subscriptions)
            )
            context.insert(zeroBill)
            context.insert(regularBill)

            sut.refresh()

            let breakdown = try #require(sut.state?.categoryBreakdown)
            #expect(breakdown.total == 15)
        }
    }

    // MARK: - Monthly Trend

    @Suite("monthlyTrend")
    @MainActor
    struct MonthlyTrend {
        @Test func whenNoBills_thenTrendHasEmptyPoints() throws {
            let referenceDate = makeDate(year: 2026, month: 6, day: 15)
            let (sut, _) = try makeSUT(currentDate: referenceDate)

            sut.refresh()

            let trend = try #require(sut.state?.monthlyTrend)
            #expect(trend.points.count == 6)
            #expect(trend.points.allSatisfy { $0.total == 0 })
        }

        @Test func whenRecurringBill_thenShowsTrendAcrossMonths() throws {
            let referenceDate = makeDate(year: 2026, month: 6, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(
                name: "Rent",
                amount: 1500,
                dueDate: makeDate(year: 2026, month: 1, day: 1),
                category: .predefined(.housing),
                recurrenceRule: RecurrenceRule(pattern: .monthly, frequency: 1)
            )
            context.insert(bill)

            sut.refresh()

            let trend = try #require(sut.state?.monthlyTrend)
            #expect(trend.points.count == 6)
            // Each month should have the recurring bill
            #expect(trend.points.allSatisfy { $0.total == 1500 })
        }

        @Test func whenBillsVaryByMonth_thenTrendReflectsVariation() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            // One-time bill in February
            let bill1 = makeBill(
                name: "One-time",
                amount: 500,
                dueDate: makeDate(year: 2026, month: 2, day: 15)
            )
            // One-time bill in March
            let bill2 = makeBill(
                name: "Another",
                amount: 300,
                dueDate: makeDate(year: 2026, month: 3, day: 10)
            )
            context.insert(bill1)
            context.insert(bill2)

            sut.refresh()

            let trend = try #require(sut.state?.monthlyTrend)
            #expect(trend.points.count == 6)

            // Find Feb and March points
            let febPoint = trend.points.first { $0.monthLabel.hasPrefix("Feb") }
            let marPoint = trend.points.first { $0.monthLabel.hasPrefix("Mar") }

            #expect(febPoint?.total == 500)
            #expect(marPoint?.total == 300)
        }

        @Test func whenPastBillPaidWithDifferentAmount_thenTrendUsesActualPaidAmount() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(name: "Electric", amount: 100, dueDate: makeDate(year: 2026, month: 2, day: 10))
            context.insert(bill)
            recordPayment(
                for: bill,
                occurrenceDueDate: bill.dueDate,
                amount: 130,
                datePaid: makeDate(year: 2026, month: 2, day: 10),
                in: context
            )

            sut.refresh()

            let trend = try #require(sut.state?.monthlyTrend)
            let febPoint = try #require(trend.points.first { $0.monthLabel.hasPrefix("Feb") })
            #expect(febPoint.total == 130)
        }
    }

    // MARK: - Category Trend

    @Suite("categoryTrend")
    @MainActor
    struct CategoryTrend {
        @Test func whenNoBills_thenCategoryTrendIsEmpty() throws {
            let referenceDate = makeDate(year: 2026, month: 6, day: 15)
            let (sut, _) = try makeSUT(currentDate: referenceDate)

            sut.refresh()

            let trend = try #require(sut.state?.categoryTrend)
            #expect(trend.points.isEmpty)
            #expect(trend.categories.isEmpty)
        }

        @Test func whenRecurringCategorizedBills_thenPointsGeneratedPerCategoryPerMonth() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(
                name: "Rent",
                amount: 1500,
                dueDate: makeDate(year: 2026, month: 1, day: 1),
                category: .predefined(.housing),
                recurrenceRule: RecurrenceRule(pattern: .monthly, frequency: 1)
            )
            context.insert(bill)

            sut.refresh()

            let trend = try #require(sut.state?.categoryTrend)
            #expect(trend.categories.map(\.id).contains(.predefined(.housing)))

            let housingPoints = trend.points.filter { $0.category == .predefined(.housing) }
            #expect(housingPoints.count >= 3) // At least Jan, Feb, Mar
        }

        @Test func whenMultipleCategoriesUsed_thenAllCategoriesIncluded() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill1 = makeBill(
                name: "Rent",
                amount: 1500,
                dueDate: makeDate(year: 2026, month: 1, day: 1),
                category: .predefined(.housing)
            )
            let bill2 = makeBill(
                name: "Internet",
                amount: 80,
                dueDate: makeDate(year: 2026, month: 1, day: 5),
                category: .predefined(.utilities)
            )
            context.insert(bill1)
            context.insert(bill2)

            sut.refresh()

            let trend = try #require(sut.state?.categoryTrend)
            #expect(trend.categories.map(\.id).contains(.predefined(.housing)))
            #expect(trend.categories.map(\.id).contains(.predefined(.utilities)))
        }

        @Test func whenCustomCategoryUsed_thenTrendUsesItsNameIconAndColor() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            context.insert(makeCustomCategory(id: "Pets", name: "Pets", iconToken: "pawprint.fill", colorHex: "#00C7BE"))
            let bill = makeBill(
                name: "Pet Food",
                amount: 150,
                dueDate: makeDate(year: 2026, month: 1, day: 1),
                category: .custom("Pets")
            )
            context.insert(bill)

            sut.refresh()

            let trend = try #require(sut.state?.categoryTrend)
            let petsLegend = try #require(trend.categories.first { $0.id == .custom("Pets") })
            #expect(petsLegend.name == "Pets")
            #expect(petsLegend.systemImageName == "pawprint.fill")
            #expect(petsLegend.colorHex == "#00C7BE")

            let petsPoint = try #require(trend.points.first { $0.category == .custom("Pets") })
            #expect(petsPoint.display.name == "Pets")
            #expect(petsPoint.display.colorHex == "#00C7BE")
        }

        @Test func whenReferencedCustomCategoryDeleted_thenTrendFoldsIntoOther() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(
                name: "Orphaned Bill",
                amount: 150,
                dueDate: makeDate(year: 2026, month: 1, day: 1),
                category: .custom("deleted-category-id")
            )
            context.insert(bill)

            sut.refresh()

            let trend = try #require(sut.state?.categoryTrend)
            #expect(trend.categories.map(\.id) == [.predefined(.other)])
            #expect(trend.points.allSatisfy { $0.category == .predefined(.other) })
        }

        @Test func whenCategoriesSorted_thenPredefinedBeforeCustom() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            context.insert(makeCustomCategory(id: "Pets", name: "Pets"))
            let customBill = makeBill(
                name: "Pet Food",
                amount: 150,
                dueDate: makeDate(year: 2026, month: 1, day: 1),
                category: .custom("Pets")
            )
            let predefinedBill = makeBill(
                name: "Rent",
                amount: 1500,
                dueDate: makeDate(year: 2026, month: 1, day: 5),
                category: .predefined(.housing)
            )
            context.insert(customBill)
            context.insert(predefinedBill)

            sut.refresh()

            let trend = try #require(sut.state?.categoryTrend)
            // Predefined categories should come before custom ones
            #expect(trend.categories.map(\.id) == [.predefined(.housing), .custom("Pets")])
        }

        @Test func whenPastBillPaidUnderCategory_thenCategoryTrendUsesActualPaidAmount() throws {
            let referenceDate = makeDate(year: 2026, month: 3, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(
                name: "Electric",
                amount: 100,
                dueDate: makeDate(year: 2026, month: 2, day: 10),
                category: .predefined(.utilities)
            )
            context.insert(bill)
            recordPayment(
                for: bill,
                occurrenceDueDate: bill.dueDate,
                amount: 130,
                datePaid: makeDate(year: 2026, month: 2, day: 10),
                in: context
            )

            sut.refresh()

            let trend = try #require(sut.state?.categoryTrend)
            let febUtilities = try #require(trend.points.first {
                $0.monthLabel.hasPrefix("Feb") && $0.category == .predefined(.utilities)
            })
            #expect(febUtilities.amount == 130)
        }
    }

    // MARK: - Recurring Bills

    @Suite("recurringBills")
    @MainActor
    struct RecurringBills {
        @Test func whenWeeklyBillInMonth_thenAllOccurrencesCounted() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            // Weekly bill starting Jan 1st, 2026
            let bill = makeBill(
                name: "Weekly",
                amount: 25,
                dueDate: makeDate(year: 2026, month: 1, day: 1),
                recurrenceRule: RecurrenceRule(pattern: .weekly, frequency: 1)
            )
            context.insert(bill)

            sut.refresh()

            let cashFlow = try #require(sut.state?.cashFlow)
            // January has ~4-5 weeks
            #expect(cashFlow.bills >= 100) // At least 4 occurrences
            #expect(cashFlow.bills <= 150) // At most 5-6 occurrences
        }

        @Test func whenRecurringIncomeInMonth_thenAllOccurrencesCounted() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            // Bi-weekly income
            let income = makeIncome(
                name: "Paycheck",
                amount: 2000,
                startDate: makeDate(year: 2026, month: 1, day: 1),
                recurrenceRule: RecurrenceRule(pattern: .weekly, frequency: 2)
            )
            context.insert(income)

            sut.refresh()

            let cashFlow = try #require(sut.state?.cashFlow)
            // Bi-weekly should have ~2 occurrences in January
            #expect(cashFlow.income >= 4000) // At least 2 occurrences
        }
    }
}

// MARK: - Assertion Helpers

@MainActor
private func totalCounts(of timing: PaymentTimingData) -> (onTime: Int, late: Int) {
    (
        onTime: timing.points.reduce(0) { $0 + $1.onTimeCount },
        late: timing.points.reduce(0) { $0 + $1.lateCount }
    )
}

// MARK: - makeSUT & Factories

@MainActor
private func makeSUT(
    currentDate: Date = Date()
) throws -> (ChartsModel, ModelContext) {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Bill.self, Income.self, PaymentEntry.self, RecurrenceRule.self,
        IssuedOccurrence.self, IncomeOccurrence.self, CustomCategory.self,
        configurations: config
    )
    let context = ModelContext(container)

    let calendar = Calendar.current
    let sut = ChartsModel(
        modelContext: context,
        calendar: calendar,
        currentDate: { currentDate }
    )

    return (sut, context)
}

private func makeBill(
    name: String = UUID().uuidString,
    amount: Decimal = Decimal(Int.random(in: 50...500)),
    dueDate: Date = Date(),
    category: CategoryIdentifier? = nil,
    recurrenceRule: RecurrenceRule? = nil
) -> Bill {
    Bill(
        name: name,
        amount: amount,
        dueDate: dueDate,
        categoryIdentifier: category,
        recurrenceRule: recurrenceRule
    )
}

private func makeCustomCategory(
    id: String = UUID().uuidString,
    name: String = UUID().uuidString,
    iconToken: String = "tag",
    colorHex: String = "#8E8E93"
) -> CustomCategory {
    CustomCategory(id: id, name: name, iconToken: iconToken, colorHex: colorHex)
}

private func makeIncome(
    name: String = UUID().uuidString,
    amount: Decimal = Decimal(Int.random(in: 1000...5000)),
    startDate: Date = Date(),
    recurrenceRule: RecurrenceRule? = nil
) -> Income {
    Income(
        name: name,
        amount: amount,
        startDate: startDate,
        recurrenceRule: recurrenceRule
    )
}

/// Records a payment against a specific occurrence of a bill, creating (or
/// reusing) the `IssuedOccurrence` snapshot the same way production payment
/// recording does.
@MainActor
@discardableResult
private func recordPayment(
    for bill: Bill,
    occurrenceDueDate: Date,
    amount: Decimal? = nil,
    datePaid: Date,
    in context: ModelContext
) -> PaymentEntry {
    let issued = bill.issuedOccurrence(for: occurrenceDueDate, calendar: .current) ?? {
        let created = IssuedOccurrence(
            occurrenceKey: bill.occurrenceKey(for: occurrenceDueDate),
            dueDate: occurrenceDueDate,
            billName: bill.name,
            billAmount: bill.amount,
            billCurrencyCode: bill.currencyCode,
            billAccountIdentifier: bill.accountIdentifier,
            billNotes: bill.notes,
            billCategoryRawValue: bill.categoryIdentifier?.rawValue,
            bill: bill
        )
        context.insert(created)
        return created
    }()

    let payment = PaymentEntry(
        amount: amount ?? bill.amount,
        datePaid: datePaid,
        issuedOccurrence: issued
    )
    context.insert(payment)
    return payment
}

/// A persisted income occurrence snapshot, standing in for a row the
/// materializer created earlier (possibly edited or excluded by the user).
@MainActor
private func makeIncomeOccurrence(
    for income: Income?,
    date: Date,
    amount: Decimal,
    isExcluded: Bool = false
) -> IncomeOccurrence {
    let occurrence = IncomeOccurrence(
        occurrenceKey: OccurrenceKey.make(stableID: income?.stableID ?? UUID().uuidString, date: date),
        date: date,
        incomeName: income?.name ?? UUID().uuidString,
        incomeAmount: amount,
        incomeCurrencyCode: income?.currencyCode ?? "USD",
        income: income
    )
    occurrence.isExcluded = isExcluded
    return occurrence
}

private func makeDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = 12
    return Calendar.current.date(from: components)!
}
