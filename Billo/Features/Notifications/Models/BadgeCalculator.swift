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
        let count = allOccurrences.filter { isIncludedInBadge($0, mode: badgeMode, referenceDate: referenceDate) }.count
        Logger.log("Badge count: \(count), mode: \(badgeMode)", level: .debug)
        return count
    }

    /// Calculates badge count from precomputed occurrences (already filtered to a reasonable horizon).
    /// Useful when the caller already has occurrences and wants to avoid recomputing them from bills.
    @MainActor
    func calculateBadgeCount(
        occurrences: [BillOccurrence],
        badgeMode: BadgeMode,
        referenceDate: Date
    ) -> Int {
        if case .never = badgeMode {
            return 0
        }

        let count = occurrences.filter { isIncludedInBadge($0, mode: badgeMode, referenceDate: referenceDate) }.count
        Logger.log("Badge count: \(count), mode: \(badgeMode)", level: .debug)
        return count
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
