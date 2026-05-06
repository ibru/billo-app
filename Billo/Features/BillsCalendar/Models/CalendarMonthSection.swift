//  Created by Jiri Urbasek on 12/05/25.

import Foundation

struct CalendarMonthSection: Identifiable, Equatable {
    let id: String
    let title: String
    let items: [CalendarListItem]

    /// Total income expected in this month
    let totalIncome: Decimal

    /// Total of bill amounts still outstanding for this month
    /// (unpaid + remaining-after-partial-payment portions of occurrences whose due date falls in the month).
    let totalBillsDue: Decimal

    /// Total of payments actually made within this month (sum of `PaymentEntry.amount` whose `datePaid` falls in the month).
    /// Used as the "paid expenses" figure for past months. Always 0 for current and future months.
    let totalPaid: Decimal

    /// True when the entire month lies before the reference date (start of today).
    /// Past months display a three-value breakdown: income / paid / outstanding.
    let isPast: Bool

    /// Net remaining = income − paid − outstanding.
    /// For non-past months `totalPaid` is 0, so this matches the previous `income − totalBillsDue` behavior.
    var netRemaining: Decimal {
        totalIncome - totalPaid - totalBillsDue
    }

    var isEmpty: Bool {
        items.count == 1 && items.first?.isEmptyMonth == true
    }

    init(
        id: String,
        title: String,
        items: [CalendarListItem],
        totalIncome: Decimal = 0,
        totalBillsDue: Decimal = 0,
        totalPaid: Decimal = 0,
        isPast: Bool = false
    ) {
        self.id = id
        self.title = title
        self.items = items
        self.totalIncome = totalIncome
        self.totalBillsDue = totalBillsDue
        self.totalPaid = totalPaid
        self.isPast = isPast
    }
}
