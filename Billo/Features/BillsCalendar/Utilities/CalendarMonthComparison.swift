//  Created by Jiri Urbasek on 12/25/25.

import Foundation

enum CalendarMonthComparison {
    static func isSameMonth(
        _ displayedMonth: DateComponents,
        as referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard let year = displayedMonth.year, let month = displayedMonth.month else { return true }
        guard let displayedDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return true }
        return calendar.isDate(displayedDate, equalTo: referenceDate, toGranularity: .month)
    }
}
