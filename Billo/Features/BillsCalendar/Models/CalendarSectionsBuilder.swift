//  Created by Jiri Urbasek on 12/05/25.

import Foundation
import SwiftData

enum CalendarSectionsBuilder {
    static func build(
        occurrences: [BillOccurrence],
        payments: [Payment],
        incomeOccurrences: [IncomeOccurrence] = [],
        from startMonth: DateComponents,
        to endMonth: DateComponents,
        referenceDate: Date,
        calendar: Calendar
    ) -> [CalendarMonthSection] {
        guard let _ = startMonth.year, let _ = startMonth.month else { return [] }
        guard let _ = endMonth.year, let _ = endMonth.month else { return [] }

        let startOfToday = calendar.startOfDay(for: referenceDate)

        var paymentsByOccurrence: [CalendarPaymentKey: [Payment]] = [:]
        paymentsByOccurrence.reserveCapacity(payments.count)
        for payment in payments {
            guard let billID = payment.bill?.persistentModelID else { continue }
            let occurrenceDay = calendar.startOfDay(for: payment.occurrenceDate)
            let key = CalendarPaymentKey(billID: billID, occurrenceDay: occurrenceDay)
            paymentsByOccurrence[key, default: []].append(payment)
        }

        var sections: [CalendarMonthSection] = []
        var current = startMonth

        while !isAfter(current, endMonth, calendar: calendar) {
            guard let monthStart = calendar.date(from: current),
                  let monthInterval = calendar.dateInterval(of: .month, for: monthStart) else {
                break
            }

            let monthOccurrences = occurrences.filter { contains($0.dueDate, in: monthInterval) }
            let monthIncomes = incomeOccurrences.filter { contains($0.date, in: monthInterval) }

            var items: [CalendarListItem] = []
            items.append(contentsOf: monthIncomes.map { .income($0) })

            for occurrence in monthOccurrences {
                let startOfDueDate = calendar.startOfDay(for: occurrence.dueDate)

                let key = CalendarPaymentKey(billID: occurrence.bill.persistentModelID, occurrenceDay: startOfDueDate)
                let occurrencePayments = paymentsByOccurrence[key] ?? []

                let isPast = startOfDueDate < startOfToday
                let isToday = startOfDueDate == startOfToday
                let hasPayments = !occurrencePayments.isEmpty

                if isPast || (isToday && hasPayments) {
                    let display = PastBillDisplay(occurrence: occurrence, payments: occurrencePayments)
                    items.append(.pastOccurrence(display))
                } else {
                    items.append(.occurrence(occurrence, payments: occurrencePayments))
                }
            }

            // Sort by date first, then by type (income → bills → empty), then by id for stability
            items.sort { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date < rhs.date
                }
                if lhs.typeSortOrder != rhs.typeSortOrder {
                    return lhs.typeSortOrder < rhs.typeSortOrder
                }
                return lhs.id < rhs.id
            }

            let sectionId = Self.sectionId(from: current)
            if items.isEmpty {
                items = [.emptyMonth(sectionId: sectionId)]
            }

            if !items.isEmpty, items.first?.isEmptyMonth != true, contains(startOfToday, in: monthInterval) {
                let insertionIndex = items.firstIndex(where: { item in
                    calendar.startOfDay(for: item.date) >= startOfToday
                }) ?? items.count

                if insertionIndex < items.count {
                    items.insert(.todayDivider(date: startOfToday, sectionId: sectionId), at: insertionIndex)
                }
            }

            // Calculate totals for the month
            let totalIncome = monthIncomes.reduce(Decimal.zero) { $0 + $1.amount }
            let totalBillsDue = monthOccurrences.reduce(Decimal.zero) { $0 + $1.amount }

            sections.append(
                CalendarMonthSection(
                    id: sectionId,
                    title: monthStart.formatted(.dateTime.month(.wide).year()),
                    items: items,
                    totalIncome: totalIncome,
                    totalBillsDue: totalBillsDue
                )
            )

            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else { break }
            current = calendar.dateComponents([.year, .month], from: nextMonth)
        }

        return sections
    }

    private static func isAfter(
        _ lhs: DateComponents,
        _ rhs: DateComponents,
        calendar: Calendar
    ) -> Bool {
        guard let lhsDate = calendar.date(from: lhs), let rhsDate = calendar.date(from: rhs) else {
            return false
        }
        return lhsDate > rhsDate
    }

    private static func sectionId(from components: DateComponents) -> String {
        let year = components.year ?? 0
        let month = components.month ?? 0
        return String(format: "%04d-%02d", year, month)
    }

    private static func contains(_ date: Date, in interval: DateInterval) -> Bool {
        date >= interval.start && date < interval.end
    }
}
