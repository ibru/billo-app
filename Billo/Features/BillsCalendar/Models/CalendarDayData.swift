//  Created by Jiri Urbasek on 12/05/25.

import Foundation
import SwiftData

/// Status of a bill on its due date. Fully-paid bills are excluded entirely
/// (they only appear as payments on their `datePaid`).
enum BillDueStatus: Equatable {
    case upcoming
    case partiallyPaid(paid: Decimal, remaining: Decimal)
    case missed
}

/// A bill occurrence displayed on its due date, with payment-aware status.
struct BillDisplay: Identifiable, Equatable {
    let occurrence: BillOccurrence
    let status: BillDueStatus

    var id: String { "bill-\(occurrence.id.billID)-\(occurrence.id.dueTime)" }

    static func == (lhs: BillDisplay, rhs: BillDisplay) -> Bool {
        lhs.occurrence == rhs.occurrence && lhs.status == rhs.status
    }
}

struct CalendarDayData: Identifiable, Equatable {
    let date: Date
    let bills: [BillDisplay]
    let payments: [PaymentEntry]
    let incomeOccurrences: [IncomeOccurrence]

    var id: Date { date }

    var hasItems: Bool {
        !bills.isEmpty ||
        !payments.isEmpty ||
        !incomeOccurrences.isEmpty
    }

    var totalDue: Decimal {
        bills.reduce(Decimal.zero) { partial, display in
            switch display.status {
            case .upcoming, .missed:
                partial + display.occurrence.amount
            case .partiallyPaid(_, let remaining):
                partial + remaining
            }
        }
    }

    var totalIncome: Decimal {
        incomeOccurrences.reduce(Decimal.zero) { partial, occurrence in
            partial + occurrence.amount
        }
    }

    init(
        date: Date,
        bills: [BillDisplay] = [],
        payments: [PaymentEntry] = [],
        incomeOccurrences: [IncomeOccurrence] = []
    ) {
        self.date = date
        self.bills = bills
        self.payments = payments
        self.incomeOccurrences = incomeOccurrences
    }

    static func == (lhs: CalendarDayData, rhs: CalendarDayData) -> Bool {
        lhs.date == rhs.date &&
        lhs.bills == rhs.bills &&
        paymentIdentifierStrings(lhs.payments) == paymentIdentifierStrings(rhs.payments) &&
        lhs.incomeOccurrences == rhs.incomeOccurrences
    }

    private static func paymentIdentifierStrings(_ payments: [PaymentEntry]) -> Set<String> {
        Set(payments.map { String(describing: $0.persistentModelID) })
    }
}

typealias CalendarMonthGridData = [Date: CalendarDayData]
