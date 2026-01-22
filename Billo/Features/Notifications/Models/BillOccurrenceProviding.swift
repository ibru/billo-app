//  Created by Jiri Urbasek on 12/02/25.

import Foundation
import SwiftData

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
    func unpaidOccurrences(
        from bills: [Bill],
        referenceDate: Date,
        horizonDays: Int,
        calendar: Calendar
    ) async -> [BillOccurrence] {
        guard !bills.isEmpty else { return [] }

        let snapshots = await MainActor.run {
            bills.map { BillOccurrenceSnapshot(from: $0, calendar: calendar) }
        }

        let seeds = await Task.detached(priority: .userInitiated) {
            guard let horizonEnd = calendar.date(byAdding: .day, value: horizonDays, to: referenceDate) else {
                return [OccurrenceSeed]()
            }

            func windowForFrequency(_ pattern: RepeatIntervalType?) -> (lookback: Int, lookahead: Int) {
                guard let pattern else {
                    return (lookback: 12, lookahead: 24)
                }

                switch pattern {
                case .weekly:
                    return (lookback: 18, lookahead: 24)
                case .monthly:
                    return (lookback: 24, lookahead: 36)
                case .yearly:
                    return (lookback: 60, lookahead: 120)
                }
            }

            func calculateNextOccurrence(
                after date: Date,
                pattern: RepeatIntervalType,
                frequency: Int,
                dayOfMonth: Int?,
                calendar: Calendar
            ) -> Date? {
                switch pattern {
                case .weekly:
                    return calendar.date(byAdding: .weekOfYear, value: frequency, to: date)

                case .monthly:
                    guard let dayOfMonth else {
                        return calendar.date(byAdding: .month, value: frequency, to: date)
                    }
                    guard let nextMonth = calendar.date(byAdding: .month, value: frequency, to: date) else {
                        return nil
                    }
                    let daysInNextMonth = calendar.range(of: .day, in: .month, for: nextMonth)?.count ?? 31
                    let adjustedDay = min(dayOfMonth, daysInNextMonth)
                    var components = calendar.dateComponents([.year, .month], from: nextMonth)
                    components.day = adjustedDay
                    return calendar.date(from: components)

                case .yearly:
                    return calendar.date(byAdding: .year, value: frequency, to: date)
                }
            }

            func generateRecurringOccurrences(
                pattern: RepeatIntervalType,
                frequency: Int,
                dayOfMonth: Int?,
                startDate: Date,
                endConditionType: EndConditionType,
                endDate: Date?,
                maxDate: Date,
                calendar: Calendar
            ) -> [Date] {
                var occurrences: [Date] = []
                var currentDate = startDate

                let effectiveEndDate: Date
                if endConditionType == .endDate, let endDate {
                    effectiveEndDate = min(endDate, maxDate)
                } else {
                    effectiveEndDate = maxDate
                }

                while currentDate <= effectiveEndDate {
                    occurrences.append(currentDate)

                    guard let nextDate = calculateNextOccurrence(
                        after: currentDate,
                        pattern: pattern,
                        frequency: frequency,
                        dayOfMonth: dayOfMonth,
                        calendar: calendar
                    ) else {
                        break
                    }

                    if nextDate > effectiveEndDate { break }
                    currentDate = nextDate
                }

                return occurrences
            }

            let referenceStartOfDay = calendar.startOfDay(for: referenceDate)
            var allSeeds: [OccurrenceSeed] = []
            allSeeds.reserveCapacity(snapshots.count * 4)

            for snapshot in snapshots {
                let (lookbackMonths, lookaheadMonths) = windowForFrequency(snapshot.recurrencePattern)

                let windowStart = calendar.date(
                    byAdding: .month,
                    value: -lookbackMonths,
                    to: referenceStartOfDay
                ) ?? referenceDate

                let windowEnd = calendar.date(
                    byAdding: .month,
                    value: lookaheadMonths,
                    to: referenceStartOfDay
                ) ?? referenceDate

                let effectiveEnd = min(windowEnd, horizonEnd)

                let allDates: [Date]
                if let pattern = snapshot.recurrencePattern {
                    allDates = generateRecurringOccurrences(
                        pattern: pattern,
                        frequency: snapshot.recurrenceFrequency,
                        dayOfMonth: snapshot.dayOfMonth,
                        startDate: snapshot.dueDate,
                        endConditionType: snapshot.endConditionType,
                        endDate: snapshot.endDate,
                        maxDate: effectiveEnd,
                        calendar: calendar
                    )
                } else {
                    allDates = [snapshot.dueDate]
                }

                for date in allDates where date >= windowStart && date <= effectiveEnd {
                    let startOfDayKey = calendar.startOfDay(for: date).timeIntervalSinceReferenceDate
                    if snapshot.fullyPaidOccurrenceStartOfDayTimes.contains(startOfDayKey) {
                        continue
                    }
                    allSeeds.append(OccurrenceSeed(billIDString: snapshot.billIDString, dueDate: date))
                }
            }

            return allSeeds.sorted { $0.dueDate < $1.dueDate }
        }.value

        return await MainActor.run {
            let billsByID = Dictionary(
                uniqueKeysWithValues: bills.map { (String(describing: $0.persistentModelID), $0) }
            )

            return seeds.compactMap { seed in
                guard let bill = billsByID[seed.billIDString] else { return nil }
                return BillOccurrence(bill: bill, dueDate: seed.dueDate)
            }
        }
    }

    // MARK: - Snapshot-based background computation

    private struct BillOccurrenceSnapshot: Sendable {
        let billIDString: String
        let dueDate: Date
        let recurrencePattern: RepeatIntervalType?
        let recurrenceFrequency: Int
        let dayOfMonth: Int?
        let endConditionType: EndConditionType
        let endDate: Date?
        let fullyPaidOccurrenceStartOfDayTimes: Set<TimeInterval>

        @MainActor
        init(from bill: Bill, calendar: Calendar) {
            self.billIDString = String(describing: bill.persistentModelID)
            self.dueDate = bill.dueDate

            if let rule = bill.recurrenceRule {
                self.recurrencePattern = rule.pattern
                self.recurrenceFrequency = rule.frequency
                self.dayOfMonth = rule.dayOfMonth
                self.endConditionType = rule.endConditionType
                self.endDate = rule.endDate
            } else {
                self.recurrencePattern = nil
                self.recurrenceFrequency = 1
                self.dayOfMonth = nil
                self.endConditionType = .never
                self.endDate = nil
            }

            // Extract fully paid occurrence dates upfront (SwiftData relationship access is @MainActor).
            // We store start-of-day time intervals for quick lookup on background threads.
            var paymentsByOccurrenceStartOfDay: [TimeInterval: Decimal] = [:]
            for payment in bill.safePayments {
                let occurrenceDay = calendar.startOfDay(for: payment.occurrenceDate)
                let key = occurrenceDay.timeIntervalSinceReferenceDate
                paymentsByOccurrenceStartOfDay[key, default: 0] += payment.amount
            }

            var fullyPaid = Set<TimeInterval>()
            for (dayTime, totalPaid) in paymentsByOccurrenceStartOfDay where totalPaid >= bill.amount {
                fullyPaid.insert(dayTime)
            }
            self.fullyPaidOccurrenceStartOfDayTimes = fullyPaid
        }
    }

    private struct OccurrenceSeed: Sendable {
        let billIDString: String
        let dueDate: Date
    }
}
