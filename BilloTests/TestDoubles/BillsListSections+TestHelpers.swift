//  Created by Jiri Urbasek on 05/13/26.

import Foundation
@testable import Billo

extension BillsListSections {
    /// Test-only convenience that generates income items in-place from raw
    /// `Income` records, mirroring the legacy production overload before
    /// `BillsModel.incomeOccurrenceItems(...)` existed.
    ///
    /// **Do not use in production.** Production code must go through
    /// `BillsModel.incomeOccurrenceItems(rangeStart:rangeEnd:referenceDate:)`
    /// so persisted history and CloudKit dedupe stay in play. This helper
    /// keeps the test surface readable by letting suites construct sections
    /// directly from a list of incomes without first computing items.
    @MainActor
    static func build(
        from bills: [Bill],
        incomes: [Income] = [],
        referenceDate: Date,
        calendar: Calendar,
        monthsAhead: Int = 3
    ) -> BillsListSections {
        let horizon = calendar.date(byAdding: .month, value: monthsAhead, to: referenceDate) ?? referenceDate
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? referenceDate
        let monthStart = calendar.dateInterval(of: .month, for: referenceDate)?.start ?? referenceDate
        let incomeRangeStart = min(weekStart, monthStart)

        let incomeItems = IncomeOccurrenceItem.generate(
            from: incomes,
            rangeStart: incomeRangeStart,
            rangeEnd: horizon,
            calendar: calendar
        )

        return build(
            from: bills,
            incomeOccurrenceItems: incomeItems,
            referenceDate: referenceDate,
            calendar: calendar,
            monthsAhead: monthsAhead
        )
    }
}
