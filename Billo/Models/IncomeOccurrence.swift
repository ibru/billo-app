//  Created by Jiri Urbasek on 12/10/25.

import Foundation
import SwiftData

/// Represents a single occurrence of an income on a specific date.
/// Value type for proper Equatable conformance in CalendarDayData.
struct IncomeOccurrence: Identifiable, Hashable {
    /// Deterministic ID following BillOccurrence.OccurrenceID pattern.
    /// Uses TimeInterval (not hashValue) for stability across launches.
    struct OccurrenceID: Hashable {
        let incomeID: PersistentIdentifier
        let dateTime: TimeInterval

        init(incomeID: PersistentIdentifier, date: Date) {
            self.incomeID = incomeID
            self.dateTime = date.timeIntervalSinceReferenceDate
        }
    }

    let id: OccurrenceID
    let income: Income
    let date: Date

    var name: String { income.name }
    var amount: Decimal { income.amount }
    var currencyCode: String { income.currencyCode }

    init(from income: Income, on date: Date) {
        self.income = income
        self.date = date
        self.id = OccurrenceID(incomeID: income.persistentModelID, date: date)
    }

    static func == (lhs: IncomeOccurrence, rhs: IncomeOccurrence) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Generating Occurrences

extension IncomeOccurrence {
    /// Generate IncomeOccurrence values from an array of incomes for a given date range.
    /// This is used by BillsListSections and calendar views.
    static func generateOccurrences(
        from incomes: [Income],
        rangeStart: Date,
        rangeEnd: Date,
        calendar: Calendar
    ) -> [IncomeOccurrence] {
        incomes.flatMap { income in
            income.generateOccurrences(from: rangeStart, until: rangeEnd, calendar: calendar)
                .map { IncomeOccurrence(from: income, on: $0) }
        }
    }
}
