//  Created by Jiri Urbasek on 12/05/25.

import Foundation

struct CalendarDayData: Identifiable, Equatable {
    let date: Date
    let occurrences: [BillOccurrence]
    let payments: [Payment]

    var id: Date { date }
    var hasItems: Bool { !occurrences.isEmpty || !payments.isEmpty }

    var totalDue: Decimal {
        occurrences.reduce(into: Decimal(0)) { partial, occurrence in
            partial += occurrence.amount
        }
    }
}

typealias CalendarMonthGridData = [Date: CalendarDayData]
