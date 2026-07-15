//  Created by Jiri Urbasek on 12/05/25.

import Foundation
import SwiftData

enum CalendarMonthGridBuilder {
    @MainActor
    static func build(
        month components: DateComponents,
        calendar: Calendar,
        occurrences: [BillOccurrence],
        payments: [PaymentEntry],
        incomeOccurrences: [IncomeOccurrenceItem] = [],
        referenceDate: Date
    ) -> CalendarMonthGridData {
        guard let monthStart = calendar.date(from: components),
              let interval = calendar.dateInterval(of: .month, for: monthStart) else {
            return [:]
        }

        var result: CalendarMonthGridData = [:]

        let startOfToday = calendar.startOfDay(for: referenceDate)

        var paymentsByOccurrence: [CalendarPaymentKey: [PaymentEntry]] = [:]
        paymentsByOccurrence.reserveCapacity(payments.count)
        for payment in payments {
            guard let billID = payment.bill?.persistentModelID else { continue }
            let occurrenceDay = calendar.startOfDay(for: payment.occurrenceDate)
            let key = CalendarPaymentKey(billID: billID, occurrenceDay: occurrenceDay)
            paymentsByOccurrence[key, default: []].append(payment)
        }

        func updateDayData(for dayKey: Date, transform: (CalendarDayData) -> CalendarDayData) {
            let existing = result[dayKey] ?? CalendarDayData(date: dayKey)
            result[dayKey] = transform(existing)
        }

        // Add income occurrences (on income date)
        for incomeOccurrence in incomeOccurrences where contains(incomeOccurrence.date, in: interval) {
            let key = calendar.startOfDay(for: incomeOccurrence.date)
            updateDayData(for: key) { existing in
                CalendarDayData(
                    date: key,
                    bills: existing.bills,
                    payments: existing.payments,
                    incomeOccurrences: existing.incomeOccurrences + [incomeOccurrence]
                )
            }
        }

        // Add bill occurrences on due date — skip fully paid bills
        for occurrence in occurrences where contains(occurrence.dueDate, in: interval) {
            let key = calendar.startOfDay(for: occurrence.dueDate)

            let paymentKey = CalendarPaymentKey(billID: occurrence.bill.persistentModelID, occurrenceDay: key)
            let occurrencePayments = paymentsByOccurrence[paymentKey] ?? []
            let totalPaid = occurrencePayments.reduce(Decimal.zero) { $0 + $1.amount }

            // `occurrence.amount` walks the bill's issued-occurrence relationship —
            // read it once per occurrence, not per comparison.
            let occurrenceAmount = occurrence.amount

            // Fully paid → skip (only the payment on datePaid represents this bill)
            if totalPaid >= occurrenceAmount { continue }

            let status: BillDueStatus
            if totalPaid > 0 {
                status = .partiallyPaid(paid: totalPaid, remaining: occurrenceAmount - totalPaid)
            } else if key < startOfToday {
                status = .missed
            } else {
                status = .upcoming
            }

            let display = BillDisplay(occurrence: occurrence, status: status)
            updateDayData(for: key) { existing in
                CalendarDayData(
                    date: key,
                    bills: existing.bills + [display],
                    payments: existing.payments,
                    incomeOccurrences: existing.incomeOccurrences
                )
            }
        }

        // Add payments (on datePaid, independent of due dates).
        // Orphaned payments (bill deleted) keep appearing via their IssuedOccurrence snapshot.
        for payment in payments where contains(payment.datePaid, in: interval) {
            let key = calendar.startOfDay(for: payment.datePaid)
            updateDayData(for: key) { existing in
                CalendarDayData(
                    date: key,
                    bills: existing.bills,
                    payments: existing.payments + [payment],
                    incomeOccurrences: existing.incomeOccurrences
                )
            }
        }

        return result
    }

    private static func contains(_ date: Date, in interval: DateInterval) -> Bool {
        date >= interval.start && date < interval.end
    }
}
