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
            bill.dueDate = calendar.startOfDay(for: newValue)
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

    var paymentsSortedDescending: [PaymentEntry] {
        bill.allPaymentEntries.sorted { $0.datePaid > $1.datePaid }
    }

    var recurrenceDescription: String? {
        recurrenceDescription()
    }

    func recurrenceDescription(locale: Locale = .autoupdatingCurrent) -> String? {
        guard let rule = bill.recurrenceRule else { return nil }

        switch rule.pattern {
        case .weekly:
            if rule.frequency == 1 {
                if let day = rule.dayOfWeek {
                    return String(
                        localized: "Weekly on \(day.displayName(locale: locale))",
                        locale: locale,
                        comment: "Recurrence description: weekly pattern with weekday"
                    )
                }

                return String(
                    localized: "Weekly",
                    locale: locale,
                    comment: "Recurrence description: weekly pattern"
                )
            }

            if let day = rule.dayOfWeek {
                return String(
                    localized: "Every \(rule.frequency) weeks on \(day.displayName(locale: locale))",
                    locale: locale,
                    comment: "Recurrence description: every N weeks with weekday"
                )
            }

            return String(
                localized: "Every \(rule.frequency) weeks",
                locale: locale,
                comment: "Recurrence description: every N weeks"
            )

        case .monthly:
            if rule.frequency == 1 {
                if let day = rule.dayOfMonth {
                    return String(
                        localized: "Monthly on the \(day.localizedOrdinal(locale: locale))",
                        locale: locale,
                        comment: "Recurrence description: monthly pattern with day-of-month ordinal"
                    )
                }

                return String(
                    localized: "Monthly",
                    locale: locale,
                    comment: "Recurrence description: monthly pattern"
                )
            }

            if let day = rule.dayOfMonth {
                return String(
                    localized: "Every \(rule.frequency) months on the \(day.localizedOrdinal(locale: locale))",
                    locale: locale,
                    comment: "Recurrence description: every N months with day-of-month ordinal"
                )
            }

            return String(
                localized: "Every \(rule.frequency) months",
                locale: locale,
                comment: "Recurrence description: every N months"
            )

        case .yearly:
            if rule.frequency == 1 {
                return String(
                    localized: "Yearly",
                    locale: locale,
                    comment: "Recurrence description: yearly pattern"
                )
            }

            return String(
                localized: "Every \(rule.frequency) years",
                locale: locale,
                comment: "Recurrence description: every N years"
            )
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
}
