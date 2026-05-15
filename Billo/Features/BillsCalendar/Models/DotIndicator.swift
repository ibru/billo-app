//  Created by Jiri Urbasek on 12/05/25.

import Foundation
import SwiftData

enum DotColor: Equatable {
    case red
    case orange
    case yellow
    case gray
    case green
    case income
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

        // Order: Income -> Payments -> Bills

        // Income (money coming in)
        for incomeOccurrence in dayData.incomeOccurrences {
            dots.append(
                DotIndicator(
                    id: "inc-\(incomeOccurrence.id.key)",
                    color: .income
                )
            )
        }

        // Payments (each payment gets its own green dot on payment date)
        for payment in dayData.payments {
            dots.append(
                DotIndicator(
                    id: "pay-\(payment.persistentModelID)",
                    color: .green
                )
            )
        }

        // Bills on due date — color based on status
        for display in dayData.bills {
            let color: DotColor = switch display.status {
            case .upcoming:
                urgencyColor(for: display.occurrence.dueDate, relativeTo: today, calendar: calendar)
            case .partiallyPaid:
                .orange
            case .missed:
                .red
            }

            dots.append(
                DotIndicator(
                    id: display.id,
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
