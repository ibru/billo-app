//  Created by Jiri Urbasek on 12/05/25.

import Foundation

struct CalendarDayData: Identifiable, Equatable {
    let date: Date
    let occurrences: [BillOccurrence]
    let payments: [Payment]
    let incomeOccurrences: [IncomeOccurrence]

    var id: Date { date }
    var hasItems: Bool { !occurrences.isEmpty || !payments.isEmpty || !incomeOccurrences.isEmpty }

    var totalDue: Decimal {
        occurrences.reduce(into: Decimal(0)) { partial, occurrence in
            partial += occurrence.amount
        }
    }

    var totalIncome: Decimal {
        incomeOccurrences.reduce(into: Decimal(0)) { partial, occurrence in
            partial += occurrence.amount
        }
    }

    init(
        date: Date,
        occurrences: [BillOccurrence],
        payments: [Payment],
        incomeOccurrences: [IncomeOccurrence] = []
    ) {
        self.date = date
        self.occurrences = occurrences
        self.payments = payments
        self.incomeOccurrences = incomeOccurrences
    }
}

typealias CalendarMonthGridData = [Date: CalendarDayData]
