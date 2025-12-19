//  Created by Jiri Urbasek on 12/05/25.

import Foundation
import SwiftData

enum CalendarListItem: Identifiable, Equatable {
    case occurrence(BillOccurrence, payments: [Payment])
    case pastOccurrence(PastBillDisplay)
    case income(IncomeOccurrence)
    case todayDivider(date: Date, sectionId: String)
    case emptyMonth(sectionId: String)

    var id: String {
        switch self {
        case .occurrence(let occurrence, _):
            return "occ-\(occurrence.id.billID)-\(occurrence.id.dueTime)"
        case .pastOccurrence(let display):
            return "past-\(display.occurrence.id.billID)-\(display.occurrence.id.dueTime)"
        case .income(let incomeOccurrence):
            return "inc-\(incomeOccurrence.id.incomeID)-\(incomeOccurrence.id.dateTime)"
        case .todayDivider(let date, let sectionId):
            return "today-\(sectionId)-\(date.timeIntervalSinceReferenceDate)"
        case .emptyMonth(let sectionId):
            return "empty-\(sectionId)"
        }
    }

    var date: Date {
        switch self {
        case .occurrence(let occurrence, _):
            return occurrence.dueDate
        case .pastOccurrence(let display):
            return display.occurrence.dueDate
        case .income(let incomeOccurrence):
            return incomeOccurrence.date
        case .todayDivider(let date, _):
            return date
        case .emptyMonth:
            return .distantFuture
        }
    }

    var isEmptyMonth: Bool {
        if case .emptyMonth = self {
            return true
        }
        return false
    }

    /// Sort order for items on the same day
    var typeSortOrder: Int {
        switch self {
        case .income: return 0
        case .pastOccurrence: return 1
        case .occurrence: return 1
        case .todayDivider: return 2
        case .emptyMonth: return 3
        }
    }

    var isPrepaid: Bool {
        if case .occurrence(_, let payments) = self {
            return !payments.isEmpty
        }
        return false
    }

    static func == (lhs: CalendarListItem, rhs: CalendarListItem) -> Bool {
        switch (lhs, rhs) {
        case (.occurrence(let lhsOccurrence, let lhsPayments), .occurrence(let rhsOccurrence, let rhsPayments)):
            return lhsOccurrence == rhsOccurrence &&
            paymentIdentifierStrings(lhsPayments) == paymentIdentifierStrings(rhsPayments)

        case (.pastOccurrence(let lhsDisplay), .pastOccurrence(let rhsDisplay)):
            return lhsDisplay == rhsDisplay

        case (.income(let lhsIncomeOccurrence), .income(let rhsIncomeOccurrence)):
            return lhsIncomeOccurrence == rhsIncomeOccurrence

        case (.todayDivider(let lhsDate, let lhsSectionId), .todayDivider(let rhsDate, let rhsSectionId)):
            return lhsDate == rhsDate && lhsSectionId == rhsSectionId

        case (.emptyMonth(let lhsSectionId), .emptyMonth(let rhsSectionId)):
            return lhsSectionId == rhsSectionId

        default:
            return false
        }
    }

    private static func paymentIdentifierStrings(_ payments: [Payment]) -> Set<String> {
        Set(payments.map { String(describing: $0.persistentModelID) })
    }
}

/// Wrapper for past bill occurrences with associated payment info.
/// Note: Custom Equatable implementation because Payment is a SwiftData @Model.
/// Hashable is intentionally NOT implemented (not needed for our use cases).
struct PastBillDisplay: Identifiable, Equatable {
    let occurrence: BillOccurrence
    let payments: [Payment]

    var id: String { "past-\(occurrence.id.billID)-\(occurrence.id.dueTime)" }

    /// Pure computation - no actor isolation needed.
    /// Derives status from payments array directly (not from Bill.totalPaid which is @MainActor).
    var status: PastBillStatus {
        if payments.isEmpty { return .missed }

        let totalPaid = payments.reduce(Decimal.zero) { partial, payment in
            partial + payment.amount
        }

        if totalPaid >= occurrence.amount { return .paid }
        return .partiallyPaid(paid: totalPaid, remaining: occurrence.amount - totalPaid)
    }

    /// For partial: returns all payments sorted by date ascending (stable ordering).
    var paymentsSortedByDate: [Payment] {
        payments.sorted { lhs, rhs in
            if lhs.datePaid != rhs.datePaid { return lhs.datePaid < rhs.datePaid }
            if lhs.createdDate != rhs.createdDate { return lhs.createdDate < rhs.createdDate }
            return String(describing: lhs.persistentModelID) < String(describing: rhs.persistentModelID)
        }
    }

    /// For fully paid: returns last payment date.
    var lastPaymentDate: Date? {
        paymentsSortedByDate.last?.datePaid
    }

    static func == (lhs: PastBillDisplay, rhs: PastBillDisplay) -> Bool {
        return lhs.occurrence == rhs.occurrence &&
        Set(lhs.payments.map { String(describing: $0.persistentModelID) }) ==
        Set(rhs.payments.map { String(describing: $0.persistentModelID) })
    }
}

enum PastBillStatus: Equatable {
    case paid
    case partiallyPaid(paid: Decimal, remaining: Decimal)
    case missed
}
