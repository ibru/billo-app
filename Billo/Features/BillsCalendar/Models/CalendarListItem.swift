//  Created by Jiri Urbasek on 12/05/25.

import Foundation
import SwiftData

enum CalendarListItem: Identifiable, Equatable {
    case occurrence(BillOccurrence)
    case payment(Payment)
    case income(IncomeOccurrence)
    case emptyMonth(sectionId: String)

    var id: String {
        switch self {
        case .occurrence(let occurrence):
            return "occ-\(occurrence.id.billID)-\(occurrence.id.dueTime)"
        case .payment(let payment):
            return "pay-\(payment.persistentModelID)"
        case .income(let incomeOccurrence):
            return "inc-\(incomeOccurrence.id.incomeID)-\(incomeOccurrence.id.dateTime)"
        case .emptyMonth(let sectionId):
            return "empty-\(sectionId)"
        }
    }

    var date: Date {
        switch self {
        case .occurrence(let occurrence):
            return occurrence.dueDate
        case .payment(let payment):
            return payment.datePaid
        case .income(let incomeOccurrence):
            return incomeOccurrence.date
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
        case .payment: return 1
        case .occurrence: return 2
        case .emptyMonth: return 3
        }
    }
}
