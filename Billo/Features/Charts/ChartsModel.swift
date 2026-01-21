//  Created by Jiri Urbasek on 01/21/26.

import SwiftData
import Foundation

@MainActor
@Observable
final class ChartsModel {
    // MARK: - Constants

    static let defaultTrendMonths = 6

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let calendar: Calendar
    private let currentDate: () -> Date

    // MARK: - Cached Formatters

    @ObservationIgnored
    private lazy var monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter
    }()

    @ObservationIgnored
    private lazy var shortMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter
    }()

    // MARK: - Published State

    private(set) var state: ChartsState?

    init(
        modelContext: ModelContext,
        calendar: Calendar = .current,
        currentDate: @escaping () -> Date = { Date() }
    ) {
        self.modelContext = modelContext
        self.calendar = calendar
        self.currentDate = currentDate
    }

    func refresh() {
        let bills = fetchBills()
        let incomes = fetchIncomes()
        let now = currentDate()

        state = ChartsState(
            cashFlow: calculateMonthlyCashFlow(bills: bills, incomes: incomes, for: now),
            categoryBreakdown: calculateCategoryBreakdown(bills: bills, for: now),
            monthlyTrend: calculateMonthlyTrend(bills: bills, for: now, monthsBack: Self.defaultTrendMonths),
            categoryTrend: calculateCategoryTrend(bills: bills, for: now, monthsBack: Self.defaultTrendMonths)
        )
    }

    // MARK: - Data Fetching

    private func fetchBills() -> [Bill] {
        let descriptor = FetchDescriptor<Bill>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchIncomes() -> [Income] {
        let descriptor = FetchDescriptor<Income>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Monthly Cash Flow Calculation

    private func calculateMonthlyCashFlow(
        bills: [Bill],
        incomes: [Income],
        for date: Date
    ) -> MonthlyCashFlowData {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else {
            return MonthlyCashFlowData(monthLabel: "", income: 0, bills: 0)
        }

        let monthStart = monthInterval.start
        let monthEnd = monthInterval.end

        // Calculate total bills due in the month
        let billsTotal = calculateBillsTotal(
            bills: bills,
            from: monthStart,
            until: monthEnd
        )

        // Calculate total income in the month
        let incomeTotal = calculateIncomeTotal(
            incomes: incomes,
            from: monthStart,
            until: monthEnd
        )

        let monthLabel = monthYearFormatter.string(from: date)

        return MonthlyCashFlowData(
            monthLabel: monthLabel,
            income: incomeTotal,
            bills: billsTotal
        )
    }

    // MARK: - Category Breakdown Calculation

    private func calculateCategoryBreakdown(
        bills: [Bill],
        for date: Date
    ) -> CategoryBreakdownData {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else {
            return CategoryBreakdownData(slices: [], total: 0, periodLabel: "")
        }

        let monthStart = monthInterval.start
        let monthEnd = monthInterval.end

        // Group bills by category and sum amounts
        var categoryTotals: [CategoryIdentifier: Decimal] = [:]

        for bill in bills {
            let occurrences = bill.generateOccurrences(
                from: monthStart,
                until: monthEnd,
                calendar: calendar
            )

            let billTotal = Decimal(occurrences.count) * bill.amount
            let category = bill.categoryIdentifier ?? .predefined(.other)

            categoryTotals[category, default: 0] += billTotal
        }

        let total = categoryTotals.values.reduce(0, +)

        let slices: [CategorySlice] = categoryTotals
            .sorted { lhs, rhs in
                // Sort by amount descending
                lhs.value > rhs.value
            }
            .map { category, amount in
                let percentage = total > 0 ? Double(truncating: (amount / total) as NSDecimalNumber) * 100 : 0

                return CategorySlice(
                    category: category,
                    amount: amount,
                    percentage: percentage
                )
            }

        let periodLabel = monthYearFormatter.string(from: date)

        return CategoryBreakdownData(
            slices: slices,
            total: total,
            periodLabel: periodLabel
        )
    }

    // MARK: - Monthly Trend Calculation

    private func calculateMonthlyTrend(
        bills: [Bill],
        for date: Date,
        monthsBack: Int
    ) -> MonthlyTrendData {
        var points: [MonthlyTrendPoint] = []

        for monthOffset in (1 - monthsBack)...0 {
            guard let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: date),
                  let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else {
                continue
            }

            let monthStart = monthInterval.start
            let monthEnd = monthInterval.end

            let totalDue = calculateBillsTotal(
                bills: bills,
                from: monthStart,
                until: monthEnd
            )

            let monthLabel = shortMonthFormatter.string(from: monthDate)

            points.append(MonthlyTrendPoint(
                month: monthStart,
                monthLabel: monthLabel,
                totalDue: totalDue
            ))
        }

        return MonthlyTrendData(points: points)
    }

    // MARK: - Category Trend Calculation

    private func calculateCategoryTrend(
        bills: [Bill],
        for date: Date,
        monthsBack: Int
    ) -> CategoryTrendData {
        var points: [CategoryTrendPoint] = []
        var usedCategories: Set<CategoryIdentifier> = []

        for monthOffset in (1 - monthsBack)...0 {
            guard let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: date),
                  let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else {
                continue
            }

            let monthStart = monthInterval.start
            let monthEnd = monthInterval.end
            let monthLabel = shortMonthFormatter.string(from: monthDate)

            // Group bills by category for this month
            var categoryTotals: [CategoryIdentifier: Decimal] = [:]

            for bill in bills {
                let occurrences = bill.generateOccurrences(
                    from: monthStart,
                    until: monthEnd,
                    calendar: calendar
                )

                let billTotal = Decimal(occurrences.count) * bill.amount
                let category = bill.categoryIdentifier ?? .predefined(.other)

                categoryTotals[category, default: 0] += billTotal
            }

            for (category, amount) in categoryTotals where amount > 0 {
                usedCategories.insert(category)
                points.append(CategoryTrendPoint(
                    month: monthStart,
                    monthLabel: monthLabel,
                    category: category,
                    amount: amount
                ))
            }
        }

        // Sort categories by their sort order (predefined first, then custom)
        let sortedCategories = usedCategories.sorted { lhs, rhs in
            lhs.sortOrder < rhs.sortOrder
        }

        return CategoryTrendData(
            points: points,
            categories: sortedCategories
        )
    }

    // MARK: - Helpers

    private func calculateBillsTotal(
        bills: [Bill],
        from start: Date,
        until end: Date
    ) -> Decimal {
        var total: Decimal = 0

        for bill in bills {
            let occurrences = bill.generateOccurrences(
                from: start,
                until: end,
                calendar: calendar
            )

            total += Decimal(occurrences.count) * bill.amount
        }

        return total
    }

    private func calculateIncomeTotal(
        incomes: [Income],
        from start: Date,
        until end: Date
    ) -> Decimal {
        var total: Decimal = 0

        for income in incomes {
            let occurrences = income.generateOccurrences(
                from: start,
                until: end,
                calendar: calendar
            )

            total += Decimal(occurrences.count) * income.amount
        }

        return total
    }
}
