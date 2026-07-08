//  Created by Jiri Urbasek on 07/01/26.

import Foundation

/// Pure decision for how editing a bill affects its schedule. Extracted from
/// `BillEditView` so the branch selection can be unit-tested without a SwiftUI harness.
enum BillEditReschedule {
    enum Outcome {
        /// Neither the displayed date nor the recurrence structure changed — keep the
        /// bill's existing anchor and rule untouched, so the picker's on-appear
        /// day-of-month re-derivation can never corrupt a clamped day (e.g. a day-31 rule).
        case metadataOnly
        /// The schedule changed — re-anchor forward to the displayed date and apply the
        /// rebuilt rule, so a new schedule takes effect forward, never retroactively from
        /// the old anchor.
        case scheduleChange(dueDate: Date, rule: RecurrenceRule?)

        var isScheduleChange: Bool {
            if case .scheduleChange = self { return true }
            return false
        }

        var newDueDate: Date? {
            if case .scheduleChange(let dueDate, _) = self { return dueDate }
            return nil
        }

        var newRule: RecurrenceRule? {
            if case .scheduleChange(_, let rule) = self { return rule }
            return nil
        }
    }

    /// - Parameters:
    ///   - seededDueDate: the date the edit screen opened with (next occurrence for recurring bills).
    ///   - editedDueDate: the date currently in the date field.
    ///   - originalRule: the bill's recurrence rule before editing.
    ///   - candidateRule: the rule the current draft controls would produce.
    ///
    /// - Note: Known, accepted short-month edge (see round-2 review SF1). Because the picker derives
    ///   `dayOfMonth` from the displayed (possibly *clamped*) date on appear, a day-31 rule whose next
    ///   occurrence lands in a short month is displayed as e.g. Feb 28. If the user then makes a *structural*
    ///   edit (frequency/end-condition) without touching the date, `candidateRule` carries the clamped day
    ///   (28) and the schedule-change branch re-anchors to it — silently downgrading 31 → 28. This is
    ///   consistent with "re-anchor to what's displayed"; we deliberately do not add bespoke day-preservation
    ///   logic. Pinned by `whenDay31StructuralEditWithClampedSeed_thenAdoptsDisplayedDay`.
    static func resolve(
        seededDueDate: Date,
        editedDueDate: Date,
        originalRule: RecurrenceRuleSnapshot?,
        candidateRule: RecurrenceRule?,
        calendar: Calendar
    ) -> Outcome {
        let dateChanged = calendar.startOfDay(for: editedDueDate)
            != calendar.startOfDay(for: seededDueDate)
        // Structural change ignores day-of-week/day-of-month: a genuine day edit moves the
        // date (→ dateChanged) rather than reading as a structural recurrence change.
        let recurrenceChanged = RecurrenceRuleSnapshot.structurallyDiffer(originalRule, candidateRule)

        guard dateChanged || recurrenceChanged else { return .metadataOnly }
        return .scheduleChange(dueDate: calendar.startOfDay(for: editedDueDate), rule: candidateRule)
    }

    /// User-facing body for the "reschedule would strand overdue bills" warning.
    /// Extracted (and unit-tested) so the plain singular/plural copy can't regress into
    /// showing raw markup. NOTE: deliberately does NOT use automatic grammar agreement
    /// (`^[…](inflect: true)`) — that markup is only resolved when the string is backed by a
    /// string-catalog entry, and would otherwise render literally to the user.
    static func rescheduleWarningMessage(for strandedDates: [Date]) -> String {
        let sorted = strandedDates.sorted()
        var items = sorted.prefix(3).map { $0.formatted(.dateTime.month(.abbreviated).day()) }
        let remaining = sorted.count - items.count
        if remaining > 0 {
            items.append(String(
                localized: "\(remaining) more",
                comment: "Trailing item in a truncated list of dates, e.g. 'Feb 2, Mar 2, and 3 more'"
            ))
        }
        // Localized list connector/separators (', ', ' and ', CJK/Arabic separators).
        let listText = items.formatted(.list(type: .and))

        if strandedDates.count == 1 {
            return String(
                localized: "1 unpaid past bill (\(listText)) will drop from your overdue list and badge if you reschedule.",
                comment: "Reschedule warning, singular: one overdue unpaid occurrence will be removed from the overdue list and badge"
            )
        }
        return String(
            localized: "\(strandedDates.count) unpaid past bills (\(listText)) will drop from your overdue list and badge if you reschedule.",
            comment: "Reschedule warning, plural: N overdue unpaid occurrences will be removed from the overdue list and badge"
        )
    }
}
