//  Created by Jiri Urbasek on 12/05/25.

import Foundation

enum CalendarMonthGridBuilder {
    @MainActor
    static func build(
        month components: DateComponents,
        calendar: Calendar,
        occurrences: [BillOccurrence],
        payments: [Payment]
    ) -> CalendarMonthGridData {
        guard let monthStart = calendar.date(from: components),
              let interval = calendar.dateInterval(of: .month, for: monthStart) else {
            return [:]
        }

        var result: CalendarMonthGridData = [:]

        for occurrence in occurrences where contains(occurrence.dueDate, in: interval) {
            let key = calendar.startOfDay(for: occurrence.dueDate)
            var dayData = result[key] ?? CalendarDayData(date: key, occurrences: [], payments: [])
            dayData = CalendarDayData(
                date: key,
                occurrences: dayData.occurrences + [occurrence],
                payments: dayData.payments
            )
            result[key] = dayData
        }

        for payment in payments where contains(payment.datePaid, in: interval) {
            let key = calendar.startOfDay(for: payment.datePaid)
            var dayData = result[key] ?? CalendarDayData(date: key, occurrences: [], payments: [])
            dayData = CalendarDayData(
                date: key,
                occurrences: dayData.occurrences,
                payments: dayData.payments + [payment]
            )
            result[key] = dayData
        }

        return result
    }

    private static func contains(_ date: Date, in interval: DateInterval) -> Bool {
        date >= interval.start && date < interval.end
    }
}
