//  Created by Jiri Urbasek on 12/02/25.

import Foundation

/// Protocol abstracting bill occurrence generation for testability
protocol BillOccurrenceProviding: Sendable {
    func unpaidOccurrences(
        from bills: [Bill],
        referenceDate: Date,
        horizonDays: Int,
        calendar: Calendar
    ) async -> [BillOccurrence]
}

/// Production implementation that calls actual Bill methods
struct BillOccurrenceProvider: BillOccurrenceProviding {
    @MainActor
    func unpaidOccurrences(
        from bills: [Bill],
        referenceDate: Date,
        horizonDays: Int,
        calendar: Calendar
    ) async -> [BillOccurrence] {
        guard let horizonEnd = calendar.date(byAdding: .day, value: horizonDays, to: referenceDate) else {
            return []
        }

        var allOccurrences: [BillOccurrence] = []

        for bill in bills {
            // Use unpaidOccurrences(aroundDate:) which includes appropriate lookback window
            // Then filter to the horizon to avoid scheduling far-future occurrences
            let unpaidDates = bill.unpaidOccurrences(
                aroundDate: referenceDate,
                calendar: calendar
            )
            .filter { $0 <= horizonEnd }  // Keep occurrences within horizon (includes overdue)

            let occurrences = unpaidDates.map { BillOccurrence(bill: bill, dueDate: $0) }
            allOccurrences.append(contentsOf: occurrences)
        }

        return allOccurrences.sorted { $0.dueDate < $1.dueDate }
    }
}
