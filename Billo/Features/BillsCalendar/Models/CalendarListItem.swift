//  Created by Jiri Urbasek on 12/05/25.

import Foundation
import SwiftData

enum CalendarListItem: Identifiable, Equatable {
    case bill(BillDisplay)
    case payment(PaymentEntry)
    case income(IncomeOccurrence)
    case todayDivider(date: Date, sectionId: String)
    case emptyMonth(sectionId: String)

    var id: String {
        switch self {
        case .bill(let display):
            return display.id
        case .payment(let payment):
            return "pay-\(payment.persistentModelID)"
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
        case .bill(let display):
            return display.occurrence.dueDate
        case .payment(let payment):
            return payment.datePaid
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
        case .bill: return 1
        case .payment: return 1
        case .todayDivider: return 2
        case .emptyMonth: return 3
        }
    }

    static func == (lhs: CalendarListItem, rhs: CalendarListItem) -> Bool {
        switch (lhs, rhs) {
        case (.bill(let lhsDisplay), .bill(let rhsDisplay)):
            return lhsDisplay == rhsDisplay

        case (.payment(let lhsPayment), .payment(let rhsPayment)):
            return String(describing: lhsPayment.persistentModelID) ==
                   String(describing: rhsPayment.persistentModelID)

        case (.income(let lhsIncome), .income(let rhsIncome)):
            return lhsIncome == rhsIncome

        case (.todayDivider(let lhsDate, let lhsSectionId), .todayDivider(let rhsDate, let rhsSectionId)):
            return lhsDate == rhsDate && lhsSectionId == rhsSectionId

        case (.emptyMonth(let lhsSectionId), .emptyMonth(let rhsSectionId)):
            return lhsSectionId == rhsSectionId

        default:
            return false
        }
    }
}
