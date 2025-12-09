//  Created by Jiri Urbasek on 11/26/25.

import SwiftData
import Foundation
import Observation

@Observable
final class BillModel {
    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let currentDate: () -> Date

    let bill: Bill

    var name: String {
        get { bill.name }
        set {
            bill.name = newValue
            bill.lastUpdatedDate = currentDate()
        }
    }

    var amount: Decimal {
        get { bill.amount }
        set {
            bill.amount = newValue
            bill.lastUpdatedDate = currentDate()
        }
    }

    var dueDate: Date {
        get { bill.dueDate }
        set {
            bill.dueDate = newValue
            bill.lastUpdatedDate = currentDate()
        }
    }

    var notes: String? {
        get { bill.notes }
        set {
            bill.notes = newValue
            bill.lastUpdatedDate = currentDate()
        }
    }

    var accountIdentifier: String? {
        get { bill.accountIdentifier }
        set {
            bill.accountIdentifier = newValue
            bill.lastUpdatedDate = currentDate()
        }
    }

    var providerURL: String? {
        get { bill.providerURL }
        set {
            bill.providerURL = newValue
            bill.lastUpdatedDate = currentDate()
        }
    }

    var categoryIdentifier: CategoryIdentifier? {
        get { bill.categoryIdentifier }
        set {
            bill.categoryIdentifier = newValue
            bill.lastUpdatedDate = currentDate()
        }
    }

    var recurrenceRule: RecurrenceRule? {
        get { bill.recurrenceRule }
        set {
            bill.recurrenceRule = newValue
            bill.lastUpdatedDate = currentDate()
        }
    }

    var currencyCode: String {
        get { bill.currencyCode }
        set {
            bill.currencyCode = newValue
            bill.lastUpdatedDate = currentDate()
        }
    }

    var paymentsSortedDescending: [Payment] {
        bill.payments.sorted { $0.datePaid > $1.datePaid }
    }

    var recurrenceDescription: String? {
        guard let rule = bill.recurrenceRule else { return nil }

        let frequencyPrefix = rule.frequency == 1 ? "" : "Every \(rule.frequency) "

        switch rule.pattern {
        case .weekly:
            if let day = rule.dayOfWeek {
                return "\(frequencyPrefix)week(s) on \(day.displayName)"
            }
            return "\(frequencyPrefix)week(s)"
        case .monthly:
            if let day = rule.dayOfMonth {
                return "\(frequencyPrefix)month(s) on the \(day)\(daySuffix(day))"
            }
            return "\(frequencyPrefix)month(s)"
        case .yearly:
            return "\(frequencyPrefix)year(s)"
        }
    }

    init(
        bill: Bill,
        modelContext: ModelContext,
        calendar: Calendar = .current,
        currentDate: @escaping () -> Date = { Date() }
    ) {
        self.bill = bill
        self.modelContext = modelContext
        self.calendar = calendar
        self.currentDate = currentDate
    }

    func save() throws {
        try modelContext.save()
    }

    func deleteBill() throws {
        modelContext.delete(bill)
        try modelContext.save()
    }

    func deletePayment(_ payment: Payment) throws {
        modelContext.delete(payment)
        try modelContext.save()
    }

    func nextOccurrences(count: Int = 3) -> [Date] {
        guard let rule = bill.recurrenceRule else { return [] }

        let startDate = bill.dueDate
        let oneYearLater = calendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate

        let occurrences = rule.generateOccurrences(
            from: startDate,
            until: oneYearLater,
            calendar: calendar
        )

        return Array(occurrences.prefix(count))
    }

    private func daySuffix(_ day: Int) -> String {
        switch day {
        case 1, 21, 31: return "st"
        case 2, 22: return "nd"
        case 3, 23: return "rd"
        default: return "th"
        }
    }
}
