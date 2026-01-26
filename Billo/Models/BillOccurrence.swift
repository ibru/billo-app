//  Created by Jiri Urbasek on 11/26/25.

import Foundation
import SwiftData

struct BillOccurrence: Identifiable, Hashable {
    struct OccurrenceID: Hashable {
        let billID: String
        let dueTime: TimeInterval

        init(billID: String, dueDate: Date) {
            self.billID = billID
            self.dueTime = dueDate.timeIntervalSinceReferenceDate
        }
    }

    let id: OccurrenceID
    let bill: Bill
    let dueDate: Date
    private let calendar: Calendar

    @MainActor
    var amount: Decimal {
        bill.snapshot(for: dueDate, calendar: calendar)?.amount ?? bill.amount
    }

    @MainActor
    var name: String {
        bill.snapshot(for: dueDate, calendar: calendar)?.name ?? bill.name
    }

    @MainActor
    var categoryIdentifier: CategoryIdentifier? {
        bill.snapshot(for: dueDate, calendar: calendar)?.categoryIdentifier ?? bill.categoryIdentifier
    }

    @MainActor
    var currencyCode: String {
        bill.snapshot(for: dueDate, calendar: calendar)?.currencyCode ?? bill.currencyCode
    }

    enum CountdownUnit: Equatable {
        case days
        case months
    }

    struct Countdown: Equatable {
        let value: Double
        let unit: CountdownUnit

        func formatted(locale: Locale) -> (value: String, unit: String) {
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .decimal

            switch unit {
            case .days:
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 0
                return (
                    formatter.string(from: NSNumber(value: value)) ?? "\(value)",
                    String(localized: "days", defaultValue: "days", locale: locale)
                )
            case .months:
                formatter.minimumFractionDigits = 1
                formatter.maximumFractionDigits = 1
                return (
                    formatter.string(from: NSNumber(value: value)) ?? "\(value)",
                    String(localized: "months", defaultValue: "months", locale: locale)
                )
            }
        }
    }

    init(bill: Bill, dueDate: Date, calendar: Calendar = .current) {
        self.bill = bill
        self.dueDate = dueDate
        self.calendar = calendar
        self.id = OccurrenceID(billID: bill.stableID, dueDate: dueDate)
    }

    @MainActor
    func status(relativeTo date: Date, calendar: Calendar) -> BillStatus {
        let total = bill.totalPaid(for: dueDate, calendar: calendar)
        if total >= bill.expectedAmount(for: dueDate, calendar: calendar) { return .paid }

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

    static func == (lhs: BillOccurrence, rhs: BillOccurrence) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    func dueCountdown(relativeTo referenceDate: Date, calendar: Calendar) -> Countdown {
        let startOfReference = calendar.startOfDay(for: referenceDate)
        let startOfDueDate = calendar.startOfDay(for: dueDate)

        let daysUntilDue = calendar.dateComponents([.day], from: startOfReference, to: startOfDueDate).day ?? 0

        if daysUntilDue < 0 {
            return Countdown(value: Double(daysUntilDue), unit: .days)
        }

        if daysUntilDue > 60 {
            let months = Double(daysUntilDue) / 30.0
            let roundedMonths = (months * 10).rounded() / 10
            return Countdown(value: roundedMonths, unit: .months)
        }

        return Countdown(value: Double(daysUntilDue), unit: .days)
    }
}
