//  Created by Jiri Urbasek on 12/05/25.

import Foundation
import SwiftData

/// Represents a future bill occurrence with its associated payments (for prepaid indicator).
/// Note: Custom Equatable implementation because PaymentEntry is a SwiftData @Model.
struct FutureOccurrenceWithPayments: Equatable {
    let occurrence: BillOccurrence
    let payments: [PaymentEntry]

    var isPrepaid: Bool { !payments.isEmpty }

    static func == (lhs: FutureOccurrenceWithPayments, rhs: FutureOccurrenceWithPayments) -> Bool {
        return lhs.occurrence == rhs.occurrence &&
        Set(lhs.payments.map { String(describing: $0.persistentModelID) }) ==
        Set(rhs.payments.map { String(describing: $0.persistentModelID) })
    }
}

struct CalendarDayData: Identifiable, Equatable {
    let date: Date
    let futureOccurrencesWithPayments: [FutureOccurrenceWithPayments]
    let pastOccurrences: [PastBillDisplay]
    let payments: [PaymentEntry]
    let incomeOccurrences: [IncomeOccurrence]

    var id: Date { date }

    /// Convenience accessor for occurrences that are due on this date (future or today without payments).
    var occurrences: [BillOccurrence] {
        futureOccurrencesWithPayments.map(\.occurrence)
    }

    var hasItems: Bool {
        !futureOccurrencesWithPayments.isEmpty ||
        !pastOccurrences.isEmpty ||
        !payments.isEmpty ||
        !incomeOccurrences.isEmpty
    }

    var totalDue: Decimal {
        let futureTotal = futureOccurrencesWithPayments.reduce(Decimal.zero) { partial, item in
            partial + item.occurrence.amount
        }
        let pastTotal = pastOccurrences.reduce(Decimal.zero) { partial, display in
            partial + display.occurrence.amount
        }
        return futureTotal + pastTotal
    }

    var totalIncome: Decimal {
        incomeOccurrences.reduce(Decimal.zero) { partial, occurrence in
            partial + occurrence.amount
        }
    }

    init(
        date: Date,
        futureOccurrencesWithPayments: [FutureOccurrenceWithPayments] = [],
        pastOccurrences: [PastBillDisplay] = [],
        payments: [PaymentEntry] = [],
        incomeOccurrences: [IncomeOccurrence] = []
    ) {
        self.date = date
        self.futureOccurrencesWithPayments = futureOccurrencesWithPayments
        self.pastOccurrences = pastOccurrences
        self.payments = payments
        self.incomeOccurrences = incomeOccurrences
    }

    static func == (lhs: CalendarDayData, rhs: CalendarDayData) -> Bool {
        lhs.date == rhs.date &&
        lhs.futureOccurrencesWithPayments == rhs.futureOccurrencesWithPayments &&
        lhs.pastOccurrences == rhs.pastOccurrences &&
        paymentIdentifierStrings(lhs.payments) == paymentIdentifierStrings(rhs.payments) &&
        lhs.incomeOccurrences == rhs.incomeOccurrences
    }

    private static func paymentIdentifierStrings(_ payments: [PaymentEntry]) -> Set<String> {
        Set(payments.map { String(describing: $0.persistentModelID) })
    }
}

typealias CalendarMonthGridData = [Date: CalendarDayData]
