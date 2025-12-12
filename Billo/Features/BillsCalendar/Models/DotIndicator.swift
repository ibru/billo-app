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
    @MainActor
    static func dots(
        for dayData: CalendarDayData,
        relativeTo today: Date,
        calendar: Calendar
    ) -> [DotIndicator] {
        var dots: [DotIndicator] = []

        // Order: Income → Payments → Bills
        // Income first (money coming in)
        for incomeOccurrence in dayData.incomeOccurrences {
            dots.append(
                DotIndicator(
                    id: "inc-\(incomeOccurrence.id.incomeID)-\(incomeOccurrence.id.dateTime)",
                    color: .income
                )
            )
        }

        // Payments second (bills already paid)
        for payment in dayData.payments {
            dots.append(
                DotIndicator(
                    id: "pay-\(payment.persistentModelID)",
                    color: .green
                )
            )
        }

        // Bill occurrences last (unpaid bills)
        for occurrence in dayData.occurrences where occurrence.status(relativeTo: today, calendar: calendar) != .paid {
            let color = urgencyColor(
                for: occurrence.dueDate,
                relativeTo: today,
                calendar: calendar
            )

            dots.append(
                DotIndicator(
                    id: "occ-\(occurrence.id.billID)-\(occurrence.id.dueTime)",
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
