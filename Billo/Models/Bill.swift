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
            Logger.log("No unpaid occurrences found", level: .info)
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

struct BillSnapshot {
    let stableID: String
    let name: String
    let amount: Decimal
    let currencyCode: String
    let dueDate: Date
    let notes: String?
    let accountIdentifier: String?
    let categoryIdentifierRawValue: String?
    let recurrenceRule: RecurrenceRuleSnapshot?

    init(bill: Bill) {
        // Use only the stable ID; persistentModelID changes after CloudKit sync
        // and would cause occurrence key mismatches across devices
        assert(!bill.stableID.isEmpty, "BillSnapshot requires Bill.stableID to be set")
        self.stableID = bill.stableID
        self.name = bill.name
        self.amount = bill.amount
        self.currencyCode = bill.currencyCode
        self.dueDate = bill.dueDate
        self.notes = bill.notes
        self.accountIdentifier = bill.accountIdentifier
        self.categoryIdentifierRawValue = bill.categoryIdentifierRawValue
        self.recurrenceRule = bill.recurrenceRule.map { RecurrenceRuleSnapshot(rule: $0) }
    }

    /// Generates all occurrences from the snapshot's original dueDate through endDate.
    /// Always anchored at dueDate to preserve the occurrence alignment from when the
    /// snapshot was captured. Use this for historical reporting of past-due bills.
    ///
    /// - Parameter endDate: The upper bound for generated occurrences
    /// - Parameter calendar: Calendar for date calculations
    /// - Returns: Array of occurrence dates, always starting from dueDate
    func generateOccurrences(
        until endDate: Date,
        calendar: Calendar
    ) -> [Date] {
        guard let rule = recurrenceRule else {
            return (dueDate <= endDate) ? [dueDate] : []
        }

        return rule.generateOccurrences(from: dueDate, until: endDate, calendar: calendar)
    }

    func occurrenceKey(for occurrenceDate: Date, calendar: Calendar) -> String {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let components = utcCalendar.dateComponents([.year, .month, .day], from: occurrenceDate)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        let dateKey = String(format: "%04d-%02d-%02d", year, month, day)
        return "\(stableID):\(dateKey)"
    }
}

struct RecurrenceRuleSnapshot {
    let pattern: RepeatIntervalType
    let frequency: Int
    let dayOfWeek: Weekday?
    let dayOfMonth: Int?
    let endConditionType: EndConditionType
    let endDate: Date?

    init(rule: RecurrenceRule) {
        self.pattern = rule.pattern
        self.frequency = rule.frequency
        self.dayOfWeek = rule.dayOfWeek
        self.dayOfMonth = rule.dayOfMonth
        self.endConditionType = rule.endConditionType
        self.endDate = rule.endDate
    }

    func generateOccurrences(
        from startDate: Date,
        until maxDate: Date,
        calendar: Calendar
    ) -> [Date] {
        RecurrenceRuleGenerator.generateOccurrences(
            pattern: pattern,
            frequency: frequency,
            dayOfWeek: dayOfWeek,
            dayOfMonth: dayOfMonth,
            endConditionType: endConditionType,
            endDate: endDate,
            from: startDate,
            until: maxDate,
            calendar: calendar
        )
    }
}

// MARK: - Bill Model

@Model
final class Bill {
    var stableID: String = UUID().uuidString
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

    @Relationship(deleteRule: .nullify, inverse: \IssuedOccurrence.bill)
    var issuedOccurrences: [IssuedOccurrence]? = []

    init(
        name: String,
        amount: Decimal,
        currencyCode: String = Locale.current.currency?.identifier ?? "USD",
        dueDate: Date,
        notes: String? = nil,
        accountIdentifier: String? = nil,
        providerURL: String? = nil,
        categoryIdentifier: CategoryIdentifier? = nil,
        recurrenceRule: RecurrenceRule? = nil,
        stableID: String? = nil
    ) {
        self.stableID = stableID ?? UUID().uuidString
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

    var safeIssuedOccurrences: [IssuedOccurrence] {
        issuedOccurrences ?? []
    }

    var allPaymentEntries: [PaymentEntry] {
        safeIssuedOccurrences.flatMap(\.safePaymentEntries)
    }
}

// MARK: - Business Logic Helpers

extension Bill {
    struct OccurrenceSnapshot {
        let name: String
        let amount: Decimal
        let currencyCode: String
        let accountIdentifier: String?
        let notes: String?
        let categoryIdentifier: CategoryIdentifier?
    }

    func occurrenceKey(for occurrenceDate: Date, calendar: Calendar) -> String {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let components = utcCalendar.dateComponents([.year, .month, .day], from: occurrenceDate)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        let dateKey = String(format: "%04d-%02d-%02d", year, month, day)
        return "\(stableID):\(dateKey)"
    }

    func issuedOccurrence(for occurrenceDate: Date, calendar: Calendar) -> IssuedOccurrence? {
        let key = occurrenceKey(for: occurrenceDate, calendar: calendar)
        return safeIssuedOccurrences.first { $0.occurrenceKey == key }
    }

    @MainActor
    func paymentEntries(for occurrenceDate: Date, calendar: Calendar) -> [PaymentEntry] {
        guard let issued = issuedOccurrence(for: occurrenceDate, calendar: calendar) else { return [] }
        return issued.safePaymentEntries
    }

    func snapshot(for occurrenceDate: Date, calendar: Calendar) -> OccurrenceSnapshot? {
        if let issued = issuedOccurrence(for: occurrenceDate, calendar: calendar) {
            return OccurrenceSnapshot(
                name: issued.billName,
                amount: issued.billAmount,
                currencyCode: issued.billCurrencyCode,
                accountIdentifier: issued.billAccountIdentifier,
                notes: issued.billNotes,
                categoryIdentifier: issued.billCategoryIdentifier
            )
        }

        return nil
    }

    func expectedAmount(for occurrenceDate: Date, calendar: Calendar) -> Decimal {
        snapshot(for: occurrenceDate, calendar: calendar)?.amount ?? amount
    }

    @MainActor
    func status(relativeTo date: Date, calendar: Calendar) -> BillStatus {
        let expectedAmount = expectedAmount(for: dueDate, calendar: calendar)
        let total = totalPaid(for: dueDate, calendar: calendar)
        if total >= expectedAmount {
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
        paymentEntries(for: occurrenceDate, calendar: calendar).isEmpty == false
    }

    @MainActor
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
        paymentEntries(for: occurrenceDate, calendar: calendar)
            .reduce(0) { $0 + $1.amount }
    }

    /// Returns true if totalPaid >= bill amount
    @MainActor
    func isFullyPaid(for occurrenceDate: Date, calendar: Calendar) -> Bool {
        totalPaid(for: occurrenceDate, calendar: calendar) >= expectedAmount(for: occurrenceDate, calendar: calendar)
    }

    /// Returns remaining balance for occurrence
    @MainActor
    func remainingBalance(for occurrenceDate: Date, calendar: Calendar) -> Decimal {
        max(0, expectedAmount(for: occurrenceDate, calendar: calendar) - totalPaid(for: occurrenceDate, calendar: calendar))
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
