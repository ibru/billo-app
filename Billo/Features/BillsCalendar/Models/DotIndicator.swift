//  Created by Jiri Urbasek on 12/05/25.

import Foundation
import SwiftData

enum DotColor: Equatable {
    case red
    case orange
    case yellow
    case gray
    case green
    case income  // New case for income
}

struct DotIndicator: Identifiable, Equatable {
    let id: String
    let color: DotColor
}

enum DotIndicatorGenerator {
    static func dots(
        for dayData: CalendarDayData,
        relativeTo today: Date,
        calendar: Calendar
    ) -> [DotIndicator] {
        var dots: [DotIndicator] = []

        // Order: Income → Payments → Past bills → Future bills

        // Income (money coming in)
        for incomeOccurrence in dayData.incomeOccurrences {
            dots.append(
                DotIndicator(
                    id: "inc-\(incomeOccurrence.id.incomeID)-\(incomeOccurrence.id.dateTime)",
                    color: .income
                )
            )
        }

        // Payments (each payment gets its own dot on payment date)
        for payment in dayData.payments {
            dots.append(
                DotIndicator(
                    id: "pay-\(payment.persistentModelID)",
                    color: .green
                )
            )
        }

        // Past occurrences (on due date) - color based on payment status
        for display in dayData.pastOccurrences {
            let color: DotColor = switch display.status {
            case .paid:
                .green
            case .partiallyPaid:
                .orange
            case .missed:
                .red
            }

            dots.append(
                DotIndicator(
                    id: "past-\(display.occurrence.id.billID)-\(display.occurrence.id.dueTime)",
                    color: color
                )
            )
        }

        // Future occurrences (on due date) - green if prepaid, otherwise urgency color
        for item in dayData.futureOccurrencesWithPayments {
            let color: DotColor = if item.isPrepaid {
                .green
            } else {
                urgencyColor(for: item.occurrence.dueDate, relativeTo: today, calendar: calendar)
            }

            dots.append(
                DotIndicator(
                    id: "occ-\(item.occurrence.id.billID)-\(item.occurrence.id.dueTime)",
                    color: color
                )
            )
        }

        return dots
    }

    static func urgencyColor(
        for dueDate: Date,
        relativeTo today: Date,
        calendar: Calendar
    ) -> DotColor {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: calendar.startOfDay(for: dueDate)).day ?? 0

        if days < 0 { return .red }
        if days == 0 { return .red }
        if days <= 7 { return .orange }
        if days <= 30 { return .yellow }
        return .gray
    }
}
