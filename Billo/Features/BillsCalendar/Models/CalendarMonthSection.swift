//  Created by Jiri Urbasek on 12/05/25.

import Foundation

struct CalendarMonthSection: Identifiable, Equatable {
    let id: String
    let title: String
    let items: [CalendarListItem]

    /// Total income expected in this month
    let totalIncome: Decimal

    /// Total bills due in this month
    let totalBillsDue: Decimal

    /// Net remaining after bills (totalIncome - totalBillsDue)
    var netRemaining: Decimal {
        totalIncome - totalBillsDue
    }

    var isEmpty: Bool {
        items.count == 1 && items.first?.isEmptyMonth == true
    }

    init(
        id: String,
        title: String,
        items: [CalendarListItem],
        totalIncome: Decimal = 0,
        totalBillsDue: Decimal = 0
    ) {
        self.id = id
        self.title = title
        self.items = items
        self.totalIncome = totalIncome
        self.totalBillsDue = totalBillsDue
    }
}
