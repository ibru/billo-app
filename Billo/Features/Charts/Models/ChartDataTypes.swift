//  Created by Jiri Urbasek on 01/21/26.

import Foundation

// MARK: - Monthly Cash Flow Data

struct MonthlyCashFlowData: Equatable {
    let monthLabel: String
    let income: Decimal
    let bills: Decimal

    var net: Decimal { income - bills }
}

// MARK: - Category Breakdown Data

struct CategorySlice: Identifiable, Equatable {
    let category: CategoryIdentifier
    let amount: Decimal
    let percentage: Double

    var id: String { category.rawValue }
    var displayName: String { category.displayName }
    var colorToken: String { category.colorToken }
}

struct CategoryBreakdownData: Equatable {
    let slices: [CategorySlice]
    let total: Decimal
    let periodLabel: String
}

// MARK: - Monthly Trend Data

struct MonthlyTrendPoint: Identifiable, Equatable {
    var id: Date { month }
    let month: Date
    let monthLabel: String
    let totalDue: Decimal
}

struct MonthlyTrendData: Equatable {
    let points: [MonthlyTrendPoint]
}

// MARK: - Category Trend Data

struct CategoryTrendPoint: Identifiable, Equatable {
    var id: String { "\(month.timeIntervalSince1970)-\(category.rawValue)" }
    let month: Date
    let monthLabel: String
    let category: CategoryIdentifier
    let amount: Decimal
}

struct CategoryTrendData: Equatable {
    let points: [CategoryTrendPoint]
    let categories: [CategoryIdentifier]
}

// MARK: - Combined Charts State

struct ChartsState: Equatable {
    let cashFlow: MonthlyCashFlowData
    let categoryBreakdown: CategoryBreakdownData
    let monthlyTrend: MonthlyTrendData
    let categoryTrend: CategoryTrendData

    var hasData: Bool {
        cashFlow.income > 0 || cashFlow.bills > 0
    }
}
