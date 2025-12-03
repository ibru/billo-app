//  Created by Jiri Urbasek on 12/02/25.

import Foundation

/// Protocol for calculating badge counts based on unpaid bills and badge mode
protocol BadgeCalculating: Sendable {
    @MainActor
    func calculateBadgeCount(
        bills: [Bill],
        badgeMode: BadgeMode,
        referenceDate: Date
    ) -> Int
}

/// Calculates badge count respecting user's badge window preference
/// This ensures consistent badge behavior across all code paths (markPaid, markUnpaid, delete, mark-from-notification)
struct BadgeCalculator: Sendable, BadgeCalculating {
    private let calendar: Calendar
    private let baseHorizonDays: Int

    init(calendar: Calendar = .current, baseHorizonDays: Int = 90) {
        self.calendar = calendar
        self.baseHorizonDays = baseHorizonDays
    }

    /// Calculates unpaid count filtered by badge mode
    /// - Parameters:
    ///   - bills: All bills to consider
    ///   - badgeMode: User's badge window preference
    ///   - referenceDate: Current date for calculations
    /// - Returns: Count of unpaid bills within the badge window
    @MainActor
    func calculateBadgeCount(
        bills: [Bill],
        badgeMode: BadgeMode,
        referenceDate: Date
    ) -> Int {
        // Never mode always returns 0
        if case .never = badgeMode {
            return 0
        }

        guard let horizonEnd = calendar.date(byAdding: .day, value: baseHorizonDays, to: referenceDate) else {
            return 0
        }

        // Collect all unpaid occurrences within horizon
        var allOccurrences: [BillOccurrence] = []
        for bill in bills {
            // Use unpaidOccurrences(aroundDate:) which includes appropriate lookback window
            // Then filter to the horizon to avoid scheduling/badging far-future occurrences
            let unpaidDates = bill.unpaidOccurrences(
                aroundDate: referenceDate,
                calendar: calendar
            )
            .filter { $0 <= horizonEnd }  // Keep occurrences within horizon (includes overdue)

            allOccurrences.append(contentsOf: unpaidDates.map { BillOccurrence(bill: bill, dueDate: $0) })
        }

        // Filter by badge window
        return allOccurrences.filter { isIncludedInBadge($0, mode: badgeMode, referenceDate: referenceDate) }.count
    }

    /// Determines if an occurrence should be included in the badge count
    @MainActor
    private func isIncludedInBadge(
        _ occurrence: BillOccurrence,
        mode: BadgeMode,
        referenceDate: Date
    ) -> Bool {
        switch mode {
        case .never:
            return false
        case .dueAndOverdue:
            let status = occurrence.status(relativeTo: referenceDate, calendar: calendar)
            return status == .dueToday || status == .overdue
        case .daysBefore(let days):
            let status = occurrence.status(relativeTo: referenceDate, calendar: calendar)
            // Always include overdue and due today
            if status == .overdue || status == .dueToday { return true }
            // Check if within the window
            let daysUntil = calendar.dateComponents([.day], from: referenceDate, to: occurrence.dueDate).day ?? 999
            return daysUntil <= days && daysUntil >= 0
        }
    }
}
