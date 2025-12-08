//  Created by Jiri Urbasek on 12/05/25.

import Foundation
import SwiftData

enum CalendarListItem: Identifiable, Equatable {
    case occurrence(BillOccurrence)
    case payment(Payment)
    case emptyMonth(sectionId: String)

    var id: String {
        switch self {
        case .occurrence(let occurrence):
            return "occ-\(occurrence.id.billID)-\(occurrence.id.dueTime)"
        case .payment(let payment):
            return "pay-\(payment.persistentModelID)"
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
}
