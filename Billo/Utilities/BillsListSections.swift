//  Created by Jiri Urbasek on 11/26/25.

import Foundation

enum BillSection: String, CaseIterable, Identifiable {
    case overdue = "Overdue"
    case today = "Today"
    case next7Days = "Next 7 Days"
    case next30Days = "Next 30 Days"
    case later = "Later"

    var id: String { rawValue }
}

struct BillsListSections {
    var occurrencesBySection: [BillSection: [BillOccurrence]]
    var monthlyTotals: MonthlyTotals
    var weeklyOverview: WeeklyOverview

    static let empty = BillsListSections(
        occurrencesBySection: [:],
        monthlyTotals: MonthlyTotals(totalDue: 0, totalPaid: 0, remaining: 0, periodLabel: ""),
        weeklyOverview: .empty
    )

    @MainActor
    static func build(
        from bills: [Bill],
        referenceDate: Date,
        calendar: Calendar
    ) -> BillsListSections {
        let threeMonthsLater = calendar.date(byAdding: .month, value: 3, to: referenceDate) ?? referenceDate

        let allOccurrences = makeOccurrences(from: bills, until: threeMonthsLater, calendar: calendar)

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
            referenceDate: referenceDate,
            calendar: calendar
        )

        let weeklyOverview = WeeklyOverview.build(
            from: allOccurrences,
            referenceDate: referenceDate,
            calendar: calendar
        )

        return BillsListSections(
            occurrencesBySection: sections,
            monthlyTotals: monthlyTotals,
            weeklyOverview: weeklyOverview
        )
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
                BillOccurrence(bill: bill, dueDate: date)
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
        referenceDate: Date,
        calendar: Calendar
    ) -> MonthlyTotals {
        guard let monthInterval = calendar.dateInterval(of: .month, for: referenceDate) else {
            return MonthlyTotals(totalDue: 0, totalPaid: 0, remaining: 0, periodLabel: "")
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
                .map { BillOccurrence(bill: bill, dueDate: $0) }

            allMonthOccurrences.append(contentsOf: occurrencesInMonth)
        }

        let totalDue = allMonthOccurrences.reduce(Decimal.zero) { $0 + $1.amount }

        let totalPaid = allMonthOccurrences.reduce(Decimal.zero) { partial, occurrence in
            let paid = occurrence.bill.totalPaid(for: occurrence.dueDate, calendar: calendar)
            return partial + min(paid, occurrence.amount)
        }

        let remaining = max(0, totalDue - totalPaid)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        let periodLabel = dateFormatter.string(from: referenceDate)

        return MonthlyTotals(
            totalDue: totalDue,
            totalPaid: totalPaid,
            remaining: remaining,
            periodLabel: periodLabel
        )
    }
}

struct MonthlyTotals {
    let totalDue: Decimal
    let totalPaid: Decimal
    let remaining: Decimal
    let periodLabel: String
}

struct WeeklyOverview {
    let weekInterval: DateInterval
    let dueCount: Int
    let dueAmount: Decimal
    let paidAmount: Decimal
    let remainingAmount: Decimal

    static let empty = WeeklyOverview(
        weekInterval: DateInterval(start: Date(), end: Date()),
        dueCount: 0,
        dueAmount: 0,
        paidAmount: 0,
        remainingAmount: 0
    )

    @MainActor
    static func build(
        from occurrences: [BillOccurrence],
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

        return WeeklyOverview(
            weekInterval: weekInterval,
            dueCount: dueCount,
            dueAmount: dueAmount,
            paidAmount: paidAmount,
            remainingAmount: remainingAmount
        )
    }
}
