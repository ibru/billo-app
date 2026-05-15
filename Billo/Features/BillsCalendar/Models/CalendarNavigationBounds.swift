//  Created by Jiri Urbasek on 12/05/25.

import Foundation

enum CalendarNavigationBounds {
    static let futureMonthLimit = 36

    static func earliestMonth(
        bills: [Bill],
        payments: [PaymentEntry],
        incomes: [Income] = [],
        incomeOccurrences: [IncomeOccurrence] = [],
        calendar: Calendar,
        currentDate: Date = Date()
    ) -> DateComponents {
        var earliest = calendar.startOfMonth(for: currentDate)

        if let earliestBill = bills.min(by: { $0.dueDate < $1.dueDate }) {
            let billMonth = calendar.startOfMonth(for: earliestBill.dueDate)
            if billMonth < earliest {
                earliest = billMonth
            }
        }

        if let earliestPayment = payments.min(by: { $0.datePaid < $1.datePaid }) {
            let paymentMonth = calendar.startOfMonth(for: earliestPayment.datePaid)
            if paymentMonth < earliest {
                earliest = paymentMonth
            }
        }

        if let earliestIncome = incomes.min(by: { $0.startDate < $1.startDate }) {
            let incomeMonth = calendar.startOfMonth(for: earliestIncome.startDate)
            if incomeMonth < earliest {
                earliest = incomeMonth
            }
        }

        // Persisted IncomeOccurrence rows survive Income deletion (deleteRule: .nullify).
        // Without considering them here, the calendar can't scroll back to months whose
        // income source was deleted — exactly the history this PR was meant to preserve.
        if let earliestOccurrence = incomeOccurrences.min(by: { $0.date < $1.date }) {
            let occurrenceMonth = calendar.startOfMonth(for: earliestOccurrence.date)
            if occurrenceMonth < earliest {
                earliest = occurrenceMonth
            }
        }

        return calendar.dateComponents([.year, .month], from: earliest)
    }

    static func latestMonth(
        from referenceDate: Date,
        calendar: Calendar,
        limit: Int = futureMonthLimit
    ) -> DateComponents {
        guard let futureDate = calendar.date(byAdding: .month, value: limit, to: referenceDate) else {
            return calendar.dateComponents([.year, .month], from: calendar.startOfMonth(for: referenceDate))
        }
        return calendar.dateComponents([.year, .month], from: calendar.startOfMonth(for: futureDate))
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
