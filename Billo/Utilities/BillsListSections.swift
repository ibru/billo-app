//  Created by Jiri Urbasek on 11/26/25.

import Foundation

enum BillSection: String, CaseIterable, Identifiable {
    case overdue
    case today
    case next7Days
    case next30Days
    case later

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .overdue: return String(localized: "Overdue")
        case .today: return String(localized: "Today")
        case .next7Days: return String(localized: "Next 7 Days")
        case .next30Days: return String(localized: "Next 30 Days")
        case .later: return String(localized: "Later")
        }
    }
}

struct BillsListSections {
    var occurrencesBySection: [BillSection: [BillOccurrence]]
    var monthlyTotals: MonthlyTotals
    var weeklyOverview: WeeklyOverview

    static let empty = BillsListSections(
        occurrencesBySection: [:],
        monthlyTotals: MonthlyTotals(
            totalDue: 0,
            totalPaid: 0,
            remaining: 0,
            periodLabel: "",
            incomeTotal: 0,
            netAmount: 0
        ),
        weeklyOverview: .empty
    )

    @MainActor
    static func build(
        from bills: [Bill],
        incomes: [Income] = [],
        referenceDate: Date,
        calendar: Calendar
    ) -> BillsListSections {
        let threeMonthsLater = calendar.date(byAdding: .month, value: 3, to: referenceDate) ?? referenceDate

        let allOccurrences = makeOccurrences(from: bills, until: threeMonthsLater, calendar: calendar)

        // Start income generation from the earlier of current week or month start
        // to ensure weekly and monthly overviews include all relevant income
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? referenceDate
        let monthStart = calendar.dateInterval(of: .month, for: referenceDate)?.start ?? referenceDate
        let incomeRangeStart = min(weekStart, monthStart)

        // Generate income occurrences ONCE for entire window
        let allIncomeOccurrences = IncomeOccurrence.generateOccurrences(
            from: incomes,
            rangeStart: incomeRangeStart,
            rangeEnd: threeMonthsLater,
            calendar: calendar
        )

        let unpaidOccurrences = allOccurrences.filter { occurrence in
            occurrence.status(relativeTo: referenceDate, calendar: calendar) != .paid
        }

        var sections: [BillSection: [BillOccurrence]] = [:]

        for occurrence in unpaidOccurrences {
            let section = determineSection(for: occurrence, relativeTo: referenceDate, calendar: calendar)
            sections[section, default: []].append(occurrence)
        }

        for key in sections.keys {
            sections[key]?.sort { $0.dueDate < $1.dueDate }
        }

        let monthlyTotals = calculateMonthlyTotals(
            bills: bills,
            incomeOccurrences: allIncomeOccurrences,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let weeklyOverview = WeeklyOverview.build(
            from: allOccurrences,
            incomeOccurrences: allIncomeOccurrences,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let result = BillsListSections(
            occurrencesBySection: sections,
            monthlyTotals: monthlyTotals,
            weeklyOverview: weeklyOverview
        )

        Logger.log(
            "Built sections - overdue: \(sections[.overdue]?.count ?? 0), today: \(sections[.today]?.count ?? 0), next7: \(sections[.next7Days]?.count ?? 0), next30: \(sections[.next30Days]?.count ?? 0), later: \(sections[.later]?.count ?? 0)",
            level: .debug
        )

        return result
    }

    @MainActor
    private static func makeOccurrences(
        from bills: [Bill],
        until endDate: Date,
        calendar: Calendar
    ) -> [BillOccurrence] {
        bills.flatMap { bill in
            let occurrenceDates = bill.generateOccurrences(
                from: bill.dueDate,
                until: endDate,
                calendar: calendar
            )
            return occurrenceDates.map { date in
                BillOccurrence(bill: bill, dueDate: date, calendar: calendar)
            }
        }
    }

    @MainActor
    private static func determineSection(
        for occurrence: BillOccurrence,
        relativeTo referenceDate: Date,
        calendar: Calendar
    ) -> BillSection {
        let status = occurrence.status(relativeTo: referenceDate, calendar: calendar)

        switch status {
        case .overdue, .partiallyPaid:
            // Partially paid items still need attention; group by timing relative to reference date
            if occurrence.dueDate < referenceDate {
                return .overdue
            }
            let sevenDaysFromNow = calendar.date(byAdding: .day, value: 7, to: referenceDate) ?? referenceDate
            if occurrence.dueDate <= sevenDaysFromNow {
                return .next7Days
            }
            let thirtyDaysFromNow = calendar.date(byAdding: .day, value: 30, to: referenceDate) ?? referenceDate
            if occurrence.dueDate <= thirtyDaysFromNow {
                return .next30Days
            }
            return .later
        case .dueToday:
            return .today
        case .upcoming, .paid:
            // Rolling 7-day window from reference date
            let sevenDaysFromNow = calendar.date(byAdding: .day, value: 7, to: referenceDate) ?? referenceDate
            // Rolling 30-day window from reference date
            let thirtyDaysFromNow = calendar.date(byAdding: .day, value: 30, to: referenceDate) ?? referenceDate

            if occurrence.dueDate <= sevenDaysFromNow {
                return .next7Days
            } else if occurrence.dueDate <= thirtyDaysFromNow {
                return .next30Days
            } else {
                return .later
            }
        }
    }

    @MainActor
    private static func calculateMonthlyTotals(
        bills: [Bill],
        incomeOccurrences: [IncomeOccurrence],
        referenceDate: Date,
        calendar: Calendar
    ) -> MonthlyTotals {
        guard let monthInterval = calendar.dateInterval(of: .month, for: referenceDate) else {
            return MonthlyTotals(
                totalDue: 0,
                totalPaid: 0,
                remaining: 0,
                periodLabel: "",
                incomeTotal: 0,
                netAmount: 0
            )
        }

        let monthStart = monthInterval.start
        let monthEnd = monthInterval.end

        var allMonthOccurrences: [BillOccurrence] = []

        for bill in bills {
            let occurrenceDates: [Date]
            if let rule = bill.recurrenceRule {
                occurrenceDates = rule.generateOccurrences(
                    from: bill.dueDate,
                    until: monthEnd,
                    calendar: calendar
                )
            } else {
                occurrenceDates = [bill.dueDate]
            }

            let occurrencesInMonth = occurrenceDates
                .filter { $0 >= monthStart && $0 < monthEnd }
                .map { BillOccurrence(bill: bill, dueDate: $0, calendar: calendar) }

            allMonthOccurrences.append(contentsOf: occurrencesInMonth)
        }

        let totalDue = allMonthOccurrences.reduce(Decimal.zero) { $0 + $1.amount }

        let totalPaid = allMonthOccurrences.reduce(Decimal.zero) { partial, occurrence in
            let paid = occurrence.bill.totalPaid(for: occurrence.dueDate, calendar: calendar)
            return partial + min(paid, occurrence.amount)
        }

        let remaining = max(0, totalDue - totalPaid)

        // Calculate income total for the month
        let monthIncomes = incomeOccurrences.filter { occurrence in
            occurrence.date >= monthStart && occurrence.date < monthEnd
        }
        let incomeTotal = monthIncomes.reduce(Decimal.zero) { $0 + $1.amount }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = .autoupdatingCurrent
        dateFormatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        let periodLabel = dateFormatter.string(from: referenceDate)

        return MonthlyTotals(
            totalDue: totalDue,
            totalPaid: totalPaid,
            remaining: remaining,
            periodLabel: periodLabel,
            incomeTotal: incomeTotal,
            netAmount: incomeTotal - totalDue
        )
    }
}

struct MonthlyTotals {
    let totalDue: Decimal
    let totalPaid: Decimal
    let remaining: Decimal
    let periodLabel: String
    let incomeTotal: Decimal
    let netAmount: Decimal  // incomeTotal - totalDue (surplus/deficit)
}

struct WeeklyOverview {
    let weekInterval: DateInterval
    let dueCount: Int
    let dueAmount: Decimal
    let paidAmount: Decimal
    let remainingAmount: Decimal
    let incomeTotal: Decimal
    let netAmount: Decimal  // incomeTotal - dueAmount (surplus/deficit)

    static let empty = WeeklyOverview(
        weekInterval: DateInterval(start: Date(), end: Date()),
        dueCount: 0,
        dueAmount: 0,
        paidAmount: 0,
        remainingAmount: 0,
        incomeTotal: 0,
        netAmount: 0
    )

    @MainActor
    static func build(
        from occurrences: [BillOccurrence],
        incomeOccurrences: [IncomeOccurrence] = [],
        referenceDate: Date,
        calendar: Calendar
    ) -> WeeklyOverview {
        // Calculate week interval (Monday to Sunday by default)
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return .empty
        }

        let weekStart = weekInterval.start
        let weekEnd = weekInterval.end

        // Filter occurrences within the week
        let weekOccurrences = occurrences.filter { occurrence in
            occurrence.dueDate >= weekStart && occurrence.dueDate < weekEnd
        }

        let dueCount = weekOccurrences.count
        let dueAmount = weekOccurrences.reduce(Decimal.zero) { $0 + $1.amount }

        let paidAmount = weekOccurrences.reduce(Decimal.zero) { partial, occurrence in
            let paid = occurrence.bill.totalPaid(for: occurrence.dueDate, calendar: calendar)
            return partial + min(paid, occurrence.amount)
        }

        let remainingAmount = max(0, dueAmount - paidAmount)

        // Calculate income total for the week
        let weekIncomes = incomeOccurrences.filter { occurrence in
            occurrence.date >= weekStart && occurrence.date < weekEnd
        }
        let incomeTotal = weekIncomes.reduce(Decimal.zero) { $0 + $1.amount }

        return WeeklyOverview(
            weekInterval: weekInterval,
            dueCount: dueCount,
            dueAmount: dueAmount,
            paidAmount: paidAmount,
            remainingAmount: remainingAmount,
            incomeTotal: incomeTotal,
            netAmount: incomeTotal - dueAmount
        )
    }
}
