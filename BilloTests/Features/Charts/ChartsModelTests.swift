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

        @Test func whenBillsInCurrentMonth_thenBillsTotalCalculated() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill1 = makeBill(name: "Rent", amount: 1500, dueDate: makeDate(year: 2026, month: 1, day: 1))
            let bill2 = makeBill(name: "Utilities", amount: 200, dueDate: makeDate(year: 2026, month: 1, day: 10))
            context.insert(bill1)
            context.insert(bill2)

            sut.refresh()

            let cashFlow = try #require(sut.state?.cashFlow)
            #expect(cashFlow.bills == 1700)
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

        @Test func whenCustomCategoryUsed_thenIncludedInBreakdown() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

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
            #expect(breakdown.slices[0].displayName == "Pets")
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
            #expect(trend.points.allSatisfy { $0.totalDue == 0 })
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
            #expect(trend.points.allSatisfy { $0.totalDue == 1500 })
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

            #expect(febPoint?.totalDue == 500)
            #expect(marPoint?.totalDue == 300)
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
            #expect(trend.categories.contains(.predefined(.housing)))

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
            #expect(trend.categories.contains(.predefined(.housing)))
            #expect(trend.categories.contains(.predefined(.utilities)))
        }

        @Test func whenCustomCategoryUsed_thenIncludedInCategoryTrend() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

            let bill = makeBill(
                name: "Pet Food",
                amount: 150,
                dueDate: makeDate(year: 2026, month: 1, day: 1),
                category: .custom("Pets")
            )
            context.insert(bill)

            sut.refresh()

            let trend = try #require(sut.state?.categoryTrend)
            #expect(trend.categories.contains(.custom("Pets")))
        }

        @Test func whenCategoriesSorted_thenPredefinedBeforeCustom() throws {
            let referenceDate = makeDate(year: 2026, month: 1, day: 15)
            let (sut, context) = try makeSUT(currentDate: referenceDate)

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
            #expect(trend.categories.count == 2)
            // Predefined categories should come before custom ones
            #expect(trend.categories[0] == .predefined(.housing))
            #expect(trend.categories[1] == .custom("Pets"))
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

// MARK: - makeSUT & Factories

@MainActor
private func makeSUT(
    currentDate: Date = Date()
) throws -> (ChartsModel, ModelContext) {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Bill.self, Income.self, PaymentEntry.self, RecurrenceRule.self,
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

private func makeDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = 12
    return Calendar.current.date(from: components)!
}
