//  Created by Jiri Urbasek on 01/21/26.

import Foundation

// MARK: - Monthly Cash Flow Data

struct MonthlyCashFlowData: Equatable {
    let monthLabel: String
    let income: Decimal

    /// Payments actually made during the month (sum of `PaymentEntry.amount`
    /// whose `datePaid` falls in the month) — mirrors the calendar's
    /// past-month "paid" figure.
    let billsPaid: Decimal

    /// Still-owed remainder of bill occurrences due during the month
    /// (unpaid + remaining-after-partial-payment portions).
    let billsOutstanding: Decimal

    var bills: Decimal { billsPaid + billsOutstanding }
    var net: Decimal { income - bills }
}

// MARK: - Category Breakdown Data

struct CategorySlice: Identifiable, Equatable {
    let category: CategoryIdentifier
    /// Resolved at data-build time so views never look up names/colors.
    let display: CategoryDisplayInfo
    let amount: Decimal
    let percentage: Double

    var id: String { category.rawValue }
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

    /// Month cost: actual payments made in the month plus the still-owed
    /// remainder of occurrences due in the month.
    let total: Decimal
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
    /// Resolved at data-build time so views never look up names/colors.
    let display: CategoryDisplayInfo
    let amount: Decimal
}

struct CategoryTrendData: Equatable {
    let points: [CategoryTrendPoint]
    let categories: [CategoryDisplayInfo]
}

// MARK: - Payment Timing Data

struct PaymentTimingMonthPoint: Identifiable, Equatable {
    var id: Date { month }
    let month: Date
    let monthLabel: String
    let onTimeCount: Int
    let lateCount: Int
}

struct PaymentTimingData: Equatable {
    let points: [PaymentTimingMonthPoint]

    /// Percentage (0–100) of payments in the window made on or before their
    /// due date. `nil` when no payment in the window carries due-date info.
    let onTimePercentage: Double?

    /// Mean of `datePaid − dueDate` in days across payments in the window.
    /// Negative means payments land early on average. `nil` when no data.
    let averageDaysLate: Double?
}

// MARK: - Combined Charts State

struct ChartsState: Equatable {
    let cashFlow: MonthlyCashFlowData
    let categoryBreakdown: CategoryBreakdownData
    let monthlyTrend: MonthlyTrendData
    let categoryTrend: CategoryTrendData
    let paymentTiming: PaymentTimingData

    /// True when any chartable records exist at all (bills, incomes, payment
    /// history, or income snapshots) — independent of the selected month, so
    /// paging to an empty month never collapses the whole screen into the
    /// global empty state.
    let hasData: Bool
}
