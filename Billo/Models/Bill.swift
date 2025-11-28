//  Created by Jiri Urbasek on 11/26/25.

import SwiftData
import Foundation

// MARK: - Supporting Types

enum BillStatus: String, Codable, CaseIterable {
    case upcoming
    case dueToday
    case overdue
    case partiallyPaid
    case paid
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
        guard !unpaidOccurrences.isEmpty else { return .noneUnpaid }

        let paymentDay = calendar.startOfDay(for: paymentDate)

        // Rule A: Single Candidate
        if unpaidOccurrences.count == 1 {
            return .certain(unpaidOccurrences[0])
        }

        let overdue = unpaidOccurrences.filter { calendar.startOfDay(for: $0) < paymentDay }
        let future = unpaidOccurrences.filter { calendar.startOfDay(for: $0) >= paymentDay }

        // Rule B: Single Future Occurrence (no distance limit)
        if overdue.isEmpty && future.count == 1 {
            return .certain(future[0])
        }

        // Rule C: Next Occurrence (paying within 14 days ahead)
        if overdue.isEmpty, let nearest = future.first {
            let daysUntil = calendar.dateComponents([.day], from: paymentDay, to: nearest).day ?? 999
            if daysUntil <= 14 && future.count > 1 {
                return .certain(nearest)
            }
        }

        // Rule D: Recent Overdue (catching up within 7 days)
        if let mostRecent = overdue.last {
            let daysSince = calendar.dateComponents([.day], from: mostRecent, to: paymentDay).day ?? 999
            if daysSince <= 7 && overdue.count == 1 {
                return .certain(mostRecent)
            }
        }

        // Rule E: Close Proximity (single occurrence within ±7 days)
        let nearby = unpaidOccurrences.filter { occurrence in
            let days = abs(calendar.dateComponents([.day], from: paymentDay, to: occurrence).day ?? 999)
            return days <= 7
        }
        if nearby.count == 1 {
            return .certain(nearby[0])
        }

        return .ambiguous(candidates: unpaidOccurrences)
    }
}

// MARK: - Bill Model

@Model
final class Bill {
    var name: String
    var amount: Decimal
    var currencyCode: String
    var dueDate: Date
    var notes: String?
    var accountIdentifier: String?
    var providerURL: String?
    var createdDate: Date
    var lastUpdatedDate: Date

    var categoryIdentifierRawValue: String?
    var recurrenceRule: RecurrenceRule?
    var payments: [Payment] = []

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
        payments.contains { payment in
            calendar.isDate(payment.occurrenceDate, inSameDayAs: occurrenceDate)
        }
    }

    func generateOccurrences(
        from startDate: Date,
        until endDate: Date,
        calendar: Calendar
    ) -> [Date] {
        guard let rule = recurrenceRule else {
            return [dueDate]
        }

        return rule.generateOccurrences(
            from: startDate,
            until: endDate,
            calendar: calendar
        )
    }

    // MARK: - Partial Payments Support

    /// Returns sum of all payments for occurrence
    @MainActor
    func totalPaid(for occurrenceDate: Date, calendar: Calendar) -> Decimal {
        payments
            .filter { payment in
                calendar.isDate(payment.occurrenceDate, inSameDayAs: occurrenceDate)
            }
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
        return allOccurrences
            .filter { $0 >= windowStart && $0 <= windowEnd }
            .filter { !isFullyPaid(for: $0, calendar: calendar) }
            .sorted()
    }

    private func windowForFrequency() -> (lookback: Int, lookahead: Int) {
        guard let rule = recurrenceRule else {
            return (lookback: 12, lookahead: 24)  // One-time: generous default
        }

        switch rule.pattern {
        case .daily:
            // Daily: 12 months back = ~365 occurrences (handles year overdue)
            // 6 months ahead = ~180 occurrences (early payment flexibility)
            return (lookback: 12, lookahead: 6)
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
