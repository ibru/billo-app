//  Created by Jiri Urbasek on 11/26/25.

import Foundation
import SwiftData

struct BillOccurrence: Identifiable, Hashable {
    struct OccurrenceID: Hashable {
        let billID: PersistentIdentifier
        let dueTime: TimeInterval

        init(billID: PersistentIdentifier, dueDate: Date) {
            self.billID = billID
            self.dueTime = dueDate.timeIntervalSinceReferenceDate
        }
    }

    let id: OccurrenceID
    let bill: Bill
    let dueDate: Date

    var amount: Decimal { bill.amount }
    var name: String { bill.name }
    var categoryIdentifier: CategoryIdentifier? { bill.categoryIdentifier }
    var currencyCode: String { bill.currencyCode }

    init(bill: Bill, dueDate: Date) {
        self.bill = bill
        self.dueDate = dueDate
        self.id = OccurrenceID(billID: bill.persistentModelID, dueDate: dueDate)
    }

    @MainActor
    func status(relativeTo date: Date, calendar: Calendar) -> BillStatus {
        let total = bill.totalPaid(for: dueDate, calendar: calendar)
        if total >= bill.amount { return .paid }

        let hasPartial = total > 0
        let comparisonResult = calendar.compare(dueDate, to: date, toGranularity: .day)

        switch comparisonResult {
        case .orderedAscending:
            return hasPartial ? .partiallyPaid : .overdue
        case .orderedSame:
            return hasPartial ? .partiallyPaid : .dueToday
        case .orderedDescending:
            return hasPartial ? .partiallyPaid : .upcoming
        }
    }

    static func == (lhs: BillOccurrence, rhs: BillOccurrence) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
