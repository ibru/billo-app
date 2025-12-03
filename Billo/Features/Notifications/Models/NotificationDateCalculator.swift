//  Created by Jiri Urbasek on 12/02/25.

import Foundation

/// Pure business logic for notification date calculations - no side effects, fully testable
struct NotificationDateCalculator: Sendable {

    /// Calculates when a notification should fire for a given due date and offset.
    ///
    /// **Past-Time Handling Rules:**
    /// 1. Target day has passed entirely → `nil` (skip, too late)
    /// 2. Target day is today but time passed → `now + 1 min` (still useful today)
    /// 3. Target day is in future → scheduled time (normal case)
    ///
    /// **Example (offset=3, bill due Dec 10, reminder time 9 AM):**
    /// - App opens Dec 5 at 8 AM → schedules Dec 7 at 9 AM ✓
    /// - App opens Dec 7 at 8 AM → schedules Dec 7 at 9 AM ✓
    /// - App opens Dec 7 at 4 PM → schedules Dec 7 at 4:01 PM ✓ (same day, time passed)
    /// - App opens Dec 8 at 8 AM → `nil` (target day Dec 7 has passed)
    ///
    /// **Rationale:**
    /// If user opens app on the target day (even after configured time), they still benefit
    /// from the reminder. Only skip if the entire target day has passed.
    ///
    /// - Parameters:
    ///   - dueDate: The bill's due date
    ///   - offsetDays: Days before due date (0 = day-of, 3 = 3 days before, etc.)
    ///   - time: Configured notification time (hour/minute)
    ///   - referenceDate: Current date/time for comparison
    ///   - calendar: Calendar for date calculations
    /// - Returns: Notification fire date, or `nil` if this reminder should be skipped
    func notificationDate(
        for dueDate: Date,
        offsetDays: Int,
        time: DateComponents,
        referenceDate: Date,
        calendar: Calendar
    ) -> Date? {
        // Calculate the target day (due date minus offset)
        guard let targetDay = calendar.date(byAdding: .day, value: -offsetDays, to: dueDate) else {
            return nil
        }

        // Set the configured time on that day
        var components = calendar.dateComponents([.year, .month, .day], from: targetDay)
        components.hour = time.hour ?? 9
        components.minute = time.minute ?? 0

        guard let notificationDate = calendar.date(from: components) else {
            return nil
        }

        // Handle past-time edge cases
        if notificationDate <= referenceDate {
            let sameDay = calendar.isDate(targetDay, inSameDayAs: referenceDate)
            if sameDay {
                // Same day but time has passed: schedule for now + 1 minute
                // User still benefits from reminder today (regardless of offset)
                return calendar.date(byAdding: .minute, value: 1, to: referenceDate)
            }
            // Target day has passed entirely: skip
            return nil
        }

        return notificationDate
    }

    /// Filters occurrences to those within the lookahead window for digest
    func occurrencesWithinLookahead(
        _ occurrences: [BillOccurrence],
        lookaheadDays: Int,
        referenceDate: Date,
        calendar: Calendar
    ) -> [BillOccurrence] {
        occurrences.filter { occurrence in
            let daysUntil = calendar.dateComponents([.day], from: referenceDate, to: occurrence.dueDate).day ?? 999
            return daysUntil <= lookaheadDays && daysUntil >= 0
        }
    }

    /// Determines how many notifications can be scheduled given the cap
    /// Returns schedulable occurrences (with offsets) and count of skipped notifications
    func schedulingPlan(
        occurrences: [BillOccurrence],
        offsets: [Int],
        maxSlots: Int
    ) -> (schedulable: [(BillOccurrence, Int)], skipped: Int) {
        var schedulable: [(BillOccurrence, Int)] = []
        var slotsUsed = 0

        for occurrence in occurrences {
            for offset in offsets {
                guard slotsUsed < maxSlots else {
                    let totalPossible = occurrences.count * offsets.count
                    return (schedulable, totalPossible - slotsUsed)
                }
                schedulable.append((occurrence, offset))
                slotsUsed += 1
            }
        }

        return (schedulable, 0)
    }
}
