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
    private let incomeProjector: IncomeOccurrenceProjector

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

    /// Snapshot of custom categories taken at the start of each `refresh()`
    /// so all calculations resolve names/colors against one consistent set.
    @ObservationIgnored
    private var customCategories: [CustomCategory] = []

    /// Existing custom-category ids for O(1) fold-to-Other checks inside the
    /// per-payment/per-occurrence bucketing loops.
    @ObservationIgnored
    private var customCategoryIDs: Set<String> = []

    /// Anchor for the month-scoped charts (cash flow, category breakdown).
    /// Trend charts stay anchored to the current date regardless.
    private(set) var selectedMonth: Date

    init(
        modelContext: ModelContext,
        calendar: Calendar = .current,
        currentDate: @escaping () -> Date = { Date() }
    ) {
        self.modelContext = modelContext
        self.calendar = calendar
        self.currentDate = currentDate
        self.selectedMonth = currentDate()
        self.incomeProjector = IncomeOccurrenceProjector(calendar: calendar)
    }

    // MARK: - Month Selection

    var isViewingCurrentMonth: Bool {
        calendar.isDate(selectedMonth, equalTo: currentDate(), toGranularity: .month)
    }

    var selectedMonthLabel: String {
        monthYearFormatter.string(from: selectedMonth)
    }

    func stepMonth(by offset: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: offset, to: selectedMonth) else { return }
        selectedMonth = newMonth
        refresh()
    }

    func resetToCurrentMonth() {
        selectedMonth = currentDate()
        refresh()
    }

    // MARK: - Refresh

    func refresh() {
        let bills = fetchBills()
        let incomes = fetchIncomes()
        let payments = fetchPayments()
        customCategories = fetchCustomCategories()
        customCategoryIDs = Set(customCategories.map(\.id))
        monthSpendingCache.removeAll()
        let now = currentDate()

        // Freeze past income occurrences as persisted snapshots (idempotent) so
        // charts read the same actual-income ledger as the home screen and
        // calendar, including per-occurrence edits and exclusions.
        do {
            try incomeProjector.materializePastOccurrences(for: incomes, upTo: now, context: modelContext)
        } catch {
            Logger.log("Charts income materialization failed: \(error)", level: .error)
        }
        let incomeOccurrences = fetchIncomeOccurrences()

        let hasData = !bills.isEmpty || !incomes.isEmpty || !payments.isEmpty || !incomeOccurrences.isEmpty

        state = ChartsState(
            cashFlow: calculateMonthlyCashFlow(
                bills: bills,
                incomes: incomes,
                incomeOccurrences: incomeOccurrences,
                payments: payments,
                for: selectedMonth,
                referenceDate: now
            ),
            categoryBreakdown: calculateCategoryBreakdown(bills: bills, payments: payments, for: selectedMonth),
            monthlyTrend: calculateMonthlyTrend(bills: bills, payments: payments, for: now, monthsBack: Self.defaultTrendMonths),
            categoryTrend: calculateCategoryTrend(bills: bills, payments: payments, for: now, monthsBack: Self.defaultTrendMonths),
            paymentTiming: calculatePaymentTiming(payments: payments, for: now, monthsBack: Self.defaultTrendMonths),
            hasData: hasData
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

    private func fetchPayments() -> [PaymentEntry] {
        let descriptor = FetchDescriptor<PaymentEntry>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchIncomeOccurrences() -> [IncomeOccurrence] {
        let descriptor = FetchDescriptor<IncomeOccurrence>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchCustomCategories() -> [CustomCategory] {
        let descriptor = FetchDescriptor<CustomCategory>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Category Resolution

    /// Buckets spending under a chartable category: `nil` and custom ids
    /// whose `CustomCategory` no longer exists fold into "Other" so deleted
    /// categories never chart as raw UUID labels.
    private func resolvedCategory(_ identifier: CategoryIdentifier?) -> CategoryIdentifier {
        guard let identifier else { return .predefined(.other) }
        if case .custom(let id) = identifier, customCategoryIDs.contains(id) == false {
            return .predefined(.other)
        }
        return identifier
    }

    /// Total lookup: `resolvedCategory` guarantees custom ids exist, so the
    /// "Other" fallback only guards against races within a single refresh.
    private func displayInfo(for identifier: CategoryIdentifier) -> CategoryDisplayInfo {
        CategoryCatalog.displayInfo(for: identifier, customCategories: customCategories)
            ?? CategoryCatalog.displayInfo(for: .other)
    }

    // MARK: - Month Spending Core

    /// A month's spending, split into money that actually left (payments made
    /// during the month, by `datePaid`) and money still owed (remainder of
    /// occurrences due during the month). Mirrors `CalendarSectionsBuilder`
    /// semantics so charts and calendar never disagree.
    private struct MonthSpending {
        var paidByCategory: [CategoryIdentifier: Decimal] = [:]
        var outstandingByCategory: [CategoryIdentifier: Decimal] = [:]

        var paidTotal: Decimal { paidByCategory.values.reduce(0, +) }
        var outstandingTotal: Decimal { outstandingByCategory.values.reduce(0, +) }
        var total: Decimal { paidTotal + outstandingTotal }

        var totalByCategory: [CategoryIdentifier: Decimal] {
            paidByCategory.merging(outstandingByCategory, uniquingKeysWith: +)
        }
    }

    /// Memo for `monthSpending` within a single `refresh()` pass. The trend
    /// charts and the month-scoped charts ask for overlapping months (14 calls,
    /// at most ~7 unique months) and each pass walks every payment plus every
    /// bill's occurrence generation and issued-occurrence relationships —
    /// too expensive to recompute for identical inputs. Cleared at the start
    /// of every `refresh()` because bills/payments are refetched there.
    @ObservationIgnored
    private var monthSpendingCache: [Date: MonthSpending] = [:]

    private func monthSpending(
        bills: [Bill],
        payments: [PaymentEntry],
        in monthInterval: DateInterval
    ) -> MonthSpending {
        if let cached = monthSpendingCache[monthInterval.start] {
            return cached
        }
        var spending = MonthSpending()

        // Actual money out: every payment made during the month, regardless of
        // which occurrence it settles. The occurrence snapshot's category
        // survives bill deletion, so orphaned history keeps its slice.
        for payment in payments where contains(payment.datePaid, in: monthInterval) {
            let category = resolvedCategory(
                payment.snapshotCategoryIdentifier ?? payment.bill?.categoryIdentifier
            )
            spending.paidByCategory[category, default: 0] += payment.amount
        }

        // Still-owed remainder of occurrences due during the month. Fully paid
        // occurrences contribute nothing here — their payments already counted
        // above in the month they were actually paid.
        for bill in bills {
            let occurrences = bill.generateOccurrences(
                from: monthInterval.start,
                until: monthInterval.end,
                calendar: calendar
            )

            for occurrence in occurrences {
                let remaining = bill.remainingBalance(for: occurrence, calendar: calendar)
                guard remaining > 0 else { continue }

                let category = resolvedCategory(
                    bill.snapshot(for: occurrence, calendar: calendar)?.categoryIdentifier
                        ?? bill.categoryIdentifier
                )
                spending.outstandingByCategory[category, default: 0] += remaining
            }
        }

        monthSpendingCache[monthInterval.start] = spending
        return spending
    }

    // MARK: - Monthly Cash Flow Calculation

    private func calculateMonthlyCashFlow(
        bills: [Bill],
        incomes: [Income],
        incomeOccurrences: [IncomeOccurrence],
        payments: [PaymentEntry],
        for date: Date,
        referenceDate: Date
    ) -> MonthlyCashFlowData {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else {
            return MonthlyCashFlowData(monthLabel: "", income: 0, billsPaid: 0, billsOutstanding: 0)
        }

        let spending = monthSpending(bills: bills, payments: payments, in: monthInterval)
        let incomeTotal = incomeProjector.items(
            rangeStart: monthInterval.start,
            rangeEnd: monthInterval.end,
            persisted: incomeOccurrences,
            incomes: incomes,
            referenceDate: referenceDate
        ).reduce(Decimal.zero) { $0 + $1.amount }

        return MonthlyCashFlowData(
            monthLabel: monthYearFormatter.string(from: date),
            income: incomeTotal,
            billsPaid: spending.paidTotal,
            billsOutstanding: spending.outstandingTotal
        )
    }

    // MARK: - Category Breakdown Calculation

    private func calculateCategoryBreakdown(
        bills: [Bill],
        payments: [PaymentEntry],
        for date: Date
    ) -> CategoryBreakdownData {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else {
            return CategoryBreakdownData(slices: [], total: 0, periodLabel: "")
        }

        let spending = monthSpending(bills: bills, payments: payments, in: monthInterval)
        let categoryTotals = spending.totalByCategory.filter { $0.value > 0 }
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
                    display: displayInfo(for: category),
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
        payments: [PaymentEntry],
        for date: Date,
        monthsBack: Int
    ) -> MonthlyTrendData {
        var points: [MonthlyTrendPoint] = []

        for monthOffset in (1 - monthsBack)...0 {
            guard let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: date),
                  let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else {
                continue
            }

            let spending = monthSpending(bills: bills, payments: payments, in: monthInterval)
            let monthLabel = shortMonthFormatter.string(from: monthDate)

            points.append(MonthlyTrendPoint(
                month: monthInterval.start,
                monthLabel: monthLabel,
                total: spending.total
            ))
        }

        return MonthlyTrendData(points: points)
    }

    // MARK: - Category Trend Calculation

    private func calculateCategoryTrend(
        bills: [Bill],
        payments: [PaymentEntry],
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

            let spending = monthSpending(bills: bills, payments: payments, in: monthInterval)
            let monthLabel = shortMonthFormatter.string(from: monthDate)

            for (category, amount) in spending.totalByCategory where amount > 0 {
                usedCategories.insert(category)
                points.append(CategoryTrendPoint(
                    month: monthInterval.start,
                    monthLabel: monthLabel,
                    category: category,
                    display: displayInfo(for: category),
                    amount: amount
                ))
            }
        }

        // Sort categories by catalog order (predefined first, then custom)
        let sortedCategories = usedCategories
            .map { displayInfo(for: $0) }
            .sorted(by: CategoryDisplayInfo.displayOrder)

        return CategoryTrendData(
            points: points,
            categories: sortedCategories
        )
    }

    // MARK: - Payment Timing Calculation

    private func calculatePaymentTiming(
        payments: [PaymentEntry],
        for date: Date,
        monthsBack: Int
    ) -> PaymentTimingData {
        var buckets: [(month: Date, interval: DateInterval, label: String)] = []

        for monthOffset in (1 - monthsBack)...0 {
            guard let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: date),
                  let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else {
                continue
            }
            buckets.append((monthInterval.start, monthInterval, shortMonthFormatter.string(from: monthDate)))
        }

        guard let windowStart = buckets.first?.interval.start,
              let windowEnd = buckets.last?.interval.end else {
            return PaymentTimingData(points: [], onTimePercentage: nil, averageDaysLate: nil)
        }

        var onTimeByMonth: [Date: Int] = [:]
        var lateByMonth: [Date: Int] = [:]
        var daysLateSamples: [Int] = []

        for payment in payments {
            // A payment without its occurrence snapshot has no due date to
            // judge against — excluding it beats pretending it was on time.
            guard let dueDate = payment.issuedOccurrence?.dueDate else { continue }
            guard payment.datePaid >= windowStart && payment.datePaid < windowEnd else { continue }

            let paidDay = calendar.startOfDay(for: payment.datePaid)
            let dueDay = calendar.startOfDay(for: dueDate)
            let daysLate = calendar.dateComponents([.day], from: dueDay, to: paidDay).day ?? 0
            daysLateSamples.append(daysLate)

            guard let bucket = buckets.first(where: { contains(payment.datePaid, in: $0.interval) }) else { continue }
            if daysLate <= 0 {
                onTimeByMonth[bucket.month, default: 0] += 1
            } else {
                lateByMonth[bucket.month, default: 0] += 1
            }
        }

        let points = buckets.map { bucket in
            PaymentTimingMonthPoint(
                month: bucket.month,
                monthLabel: bucket.label,
                onTimeCount: onTimeByMonth[bucket.month] ?? 0,
                lateCount: lateByMonth[bucket.month] ?? 0
            )
        }

        guard daysLateSamples.isEmpty == false else {
            return PaymentTimingData(points: points, onTimePercentage: nil, averageDaysLate: nil)
        }

        let onTimeCount = daysLateSamples.filter { $0 <= 0 }.count
        return PaymentTimingData(
            points: points,
            onTimePercentage: Double(onTimeCount) / Double(daysLateSamples.count) * 100,
            averageDaysLate: Double(daysLateSamples.reduce(0, +)) / Double(daysLateSamples.count)
        )
    }

    // MARK: - Helpers

    /// Half-open containment `[start, end)` — matches `CalendarSectionsBuilder`.
    private func contains(_ date: Date, in interval: DateInterval) -> Bool {
        date >= interval.start && date < interval.end
    }
}
