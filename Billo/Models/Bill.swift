//  Created by Jiri Urbasek on 11/26/25.

import SwiftData
import Foundation

// MARK: - Supporting Types

enum BillStatus: String, Codable, CaseIterable {
    case upcoming = "upcoming"
    case dueToday = "dueToday"
    case overdue = "overdue"
    case partiallyPaid = "partiallyPaid"
    case paid = "paid"
}

struct OccurrenceDetector {
    let calendar: Calendar

    enum DetectionResult: Equatable {
        case certain(Date)
        case ambiguous(candidates: [Date])
        case noneUnpaid  // All occurrences fully paid
    }

    nonisolated func detectOccurrence(
        for paymentDate: Date,
        from unpaidOccurrences: [Date]
    ) -> DetectionResult {
        Logger.log("Detecting occurrence for payment on \(paymentDate), candidates: \(unpaidOccurrences.count)", level: .debug)

        guard !unpaidOccurrences.isEmpty else {
            Logger.log("No unpaid occurrences found", level: .warning)
            return .noneUnpaid
        }

        let paymentDay = calendar.startOfDay(for: paymentDate)

        // Rule A: Single Candidate
        if unpaidOccurrences.count == 1 {
            Logger.log("Matched rule A (single candidate): \(unpaidOccurrences[0])", level: .debug)
            return .certain(unpaidOccurrences[0])
        }

        let overdue = unpaidOccurrences.filter { calendar.startOfDay(for: $0) < paymentDay }
        let future = unpaidOccurrences.filter { calendar.startOfDay(for: $0) >= paymentDay }

        // Rule B: Single Future Occurrence (no distance limit)
        if overdue.isEmpty && future.count == 1 {
            Logger.log("Matched rule B (single future): \(future[0])", level: .debug)
            return .certain(future[0])
        }

        // Rule C: Next Occurrence (paying within 14 days ahead)
        if overdue.isEmpty, let nearest = future.first {
            let daysUntil = calendar.dateComponents([.day], from: paymentDay, to: nearest).day ?? 999
            if daysUntil <= 14 && future.count > 1 {
                Logger.log("Matched rule C (next occurrence within 14 days): \(nearest)", level: .debug)
                return .certain(nearest)
            }
        }

        // Rule D: Recent Overdue (catching up within 7 days)
        if let mostRecent = overdue.last {
            let daysSince = calendar.dateComponents([.day], from: mostRecent, to: paymentDay).day ?? 999
            if daysSince <= 7 && overdue.count == 1 {
                Logger.log("Matched rule D (recent overdue within 7 days): \(mostRecent)", level: .debug)
                return .certain(mostRecent)
            }
        }

        // Rule E: Close Proximity (single occurrence within ±7 days)
        let nearby = unpaidOccurrences.filter { occurrence in
            let days = abs(calendar.dateComponents([.day], from: paymentDay, to: occurrence).day ?? 999)
            return days <= 7
        }
        if nearby.count == 1 {
            Logger.log("Matched rule E (close proximity ±7 days): \(nearby[0])", level: .debug)
            return .certain(nearby[0])
        }

        Logger.log("No rule matched, ambiguous with \(unpaidOccurrences.count) candidates", level: .warning)
        return .ambiguous(candidates: unpaidOccurrences)
    }
}

// MARK: - Bill Model

@Model
final class Bill {
    var name: String = ""
    var amount: Decimal = 0
    var currencyCode: String = "USD"
    var dueDate: Date = Date()
    var notes: String?
    var accountIdentifier: String?
    var providerURL: String?
    var createdDate: Date = Date()
    var lastUpdatedDate: Date = Date()

    var categoryIdentifierRawValue: String?

    @Relationship(deleteRule: .cascade, inverse: \RecurrenceRule.bill)
    var recurrenceRule: RecurrenceRule?

    @Relationship(deleteRule: .cascade, inverse: \Payment.bill)
    var payments: [Payment]? = []

    init(
        name: String,
        amount: Decimal,
        currencyCode: String = Locale.current.currency?.identifier ?? "USD",
        dueDate: Date,
        notes: String? = nil,
        accountIdentifier: String? = nil,
        providerURL: String? = nil,
        categoryIdentifier: CategoryIdentifier? = nil,
        recurrenceRule: RecurrenceRule? = nil
    ) {
        self.name = name
        self.amount = amount
        self.currencyCode = currencyCode
        self.dueDate = dueDate
        self.notes = notes
        self.accountIdentifier = accountIdentifier
        self.providerURL = providerURL
        self.categoryIdentifierRawValue = categoryIdentifier?.rawValue
        self.recurrenceRule = recurrenceRule
        self.createdDate = Date()
        self.lastUpdatedDate = Date()
    }
}

extension Bill {
    var categoryIdentifier: CategoryIdentifier? {
        get { categoryIdentifierRawValue.flatMap(CategoryIdentifier.init(rawValue:)) }
        set { categoryIdentifierRawValue = newValue?.rawValue }
    }

    /// Safe accessor for payments that handles CloudKit's optional relationship requirement.
    /// Use this for reading; for mutations use `payments` directly.
    var safePayments: [Payment] {
        payments ?? []
    }
}

// MARK: - Business Logic Helpers

extension Bill {
    @MainActor
    func status(relativeTo date: Date, calendar: Calendar) -> BillStatus {
        let total = totalPaid(for: dueDate, calendar: calendar)
        if total >= amount {
            return .paid
        }

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

    @MainActor
    func hasPayment(for occurrenceDate: Date, calendar: Calendar) -> Bool {
        safePayments.contains { payment in
            calendar.isDate(payment.occurrenceDate, inSameDayAs: occurrenceDate)
        }
    }

    func generateOccurrences(
        from startDate: Date,
        until endDate: Date,
        calendar: Calendar
    ) -> [Date] {
        guard let rule = recurrenceRule else {
            return (dueDate >= startDate && dueDate <= endDate) ? [dueDate] : []
        }

        // IMPORTANT:
        // Always generate from the original `dueDate` (anchor) and then filter to the requested window.
        // Generating from `startDate` would shift the schedule (e.g., everything becomes due on the 1st),
        // and payments keyed by real occurrence dates would no longer match.
        let allOccurrences = rule.generateOccurrences(
            from: dueDate,
            until: endDate,
            calendar: calendar
        )

        return allOccurrences.filter { $0 >= startDate }
    }

    // MARK: - Partial Payments Support

    /// Returns sum of all payments for occurrence
    @MainActor
    func totalPaid(for occurrenceDate: Date, calendar: Calendar) -> Decimal {
        safePayments
            .filter { calendar.isDate($0.occurrenceDate, inSameDayAs: occurrenceDate) }
            .reduce(0) { $0 + $1.amount }
    }

    /// Returns true if totalPaid >= bill amount
    @MainActor
    func isFullyPaid(for occurrenceDate: Date, calendar: Calendar) -> Bool {
        totalPaid(for: occurrenceDate, calendar: calendar) >= amount
    }

    /// Returns remaining balance for occurrence
    @MainActor
    func remainingBalance(for occurrenceDate: Date, calendar: Calendar) -> Decimal {
        max(0, amount - totalPaid(for: occurrenceDate, calendar: calendar))
    }

    // MARK: - Occurrence Generation with Partial Payment Support

    /// Returns unpaid occurrences around a reference date (typically "today")
    ///
    /// This method uses frequency-based lookback/lookahead windows to include:
    /// - Overdue occurrences within the lookback window (e.g., 24 months for monthly bills)
    /// - Current and future occurrences within the lookahead window (e.g., 36 months for monthly bills)
    ///
    /// **Window Policy:**
    /// - Generates occurrences from the bill's original `dueDate` to preserve weekday alignment
    /// - Filters to `[referenceDate - lookback, referenceDate + lookahead]`
    /// - Prevents unbounded historical queries while including relevant overdue bills
    ///
    /// **Usage:**
    /// For notification scheduling and badge counts, callers should filter the results to their horizon:
    /// ```swift
    /// let occurrences = bill.unpaidOccurrences(aroundDate: today, calendar: calendar)
    ///     .filter { $0 <= horizonEnd }  // Limit to scheduling/display horizon
    /// ```
    ///
    /// - Parameters:
    ///   - referenceDate: The date to center the search window around (typically "today")
    ///   - calendar: Calendar for date calculations
    /// - Returns: Sorted array of dates for unpaid occurrences within the window
    @MainActor
    func unpaidOccurrences(
        aroundDate referenceDate: Date,
        calendar: Calendar
    ) -> [Date] {
        // Determine lookback/lookahead based on frequency
        let (lookbackMonths, lookaheadMonths) = windowForFrequency()

        // Compute window bounds
        let windowStart = calendar.date(
            byAdding: .month,
            value: -lookbackMonths,
            to: calendar.startOfDay(for: referenceDate)
        ) ?? referenceDate

        let windowEnd = calendar.date(
            byAdding: .month,
            value: lookaheadMonths,
            to: calendar.startOfDay(for: referenceDate)
        ) ?? referenceDate

        // Generate occurrences anchored at the original dueDate to preserve weekday alignment
        let allOccurrences = generateOccurrences(
            from: dueDate,
            until: windowEnd,
            calendar: calendar
        )

        // Filter to window and NOT fully paid (allows partial payments to continue)
        let result = allOccurrences
            .filter { $0 >= windowStart && $0 <= windowEnd }
            .filter { !isFullyPaid(for: $0, calendar: calendar) }
            .sorted()

        Logger.log("Unpaid occurrences for \(name): \(result.count)", level: .debug)
        return result
    }

    private func windowForFrequency() -> (lookback: Int, lookahead: Int) {
        guard let rule = recurrenceRule else {
            return (lookback: 12, lookahead: 24)  // One-time: generous default
        }

        switch rule.pattern {
        case .weekly:
            // Weekly: 18 months back = ~78 occurrences (1.5 year overdue)
            // 24 months ahead = ~104 occurrences (2 year advance payment)
            return (lookback: 18, lookahead: 24)
        case .monthly:
            // Monthly: 24 months back = 24 occurrences (2 year overdue)
            // 36 months ahead = 36 occurrences (3 year advance)
            return (lookback: 24, lookahead: 36)
        case .yearly:
            // Yearly: 60 months back = 5 occurrences (5 year overdue)
            // 120 months ahead = 10 occurrences (10 year advance)
            return (lookback: 60, lookahead: 120)
        }
    }

    // MARK: - Public Detection API

    @MainActor
    func detectOccurrence(
        for paymentDate: Date,
        calendar: Calendar
    ) -> OccurrenceDetector.DetectionResult {
        let unpaidDates = unpaidOccurrences(
            aroundDate: paymentDate,
            calendar: calendar
        )

        let detector = OccurrenceDetector(calendar: calendar)
        return detector.detectOccurrence(for: paymentDate, from: unpaidDates)
    }
}
