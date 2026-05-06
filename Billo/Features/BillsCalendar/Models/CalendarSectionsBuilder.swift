//  Created by Jiri Urbasek on 12/05/25.

import Foundation
import SwiftData

enum CalendarSectionsBuilder {
    #if DEBUG
    /// Enables more verbose tracing that logs individual item decisions.
    ///
    /// Enable via:
    /// - Xcode Scheme -> Run -> Arguments -> Environment Variables:
    ///   - `BILLO_CALENDAR_TRACE_VERBOSE=1`
    /// - or runtime defaults:
    ///   - `UserDefaults.standard.set(true, forKey: "BILLO_CALENDAR_TRACE_VERBOSE")`
    private static var isVerboseTraceEnabled: Bool {
        ProcessInfo.processInfo.environment["BILLO_CALENDAR_TRACE_VERBOSE"] == "1"
            || UserDefaults.standard.bool(forKey: "BILLO_CALENDAR_TRACE_VERBOSE")
    }
    #else
    private static var isVerboseTraceEnabled: Bool { false }
    #endif

    static func build(
        occurrences: [BillOccurrence],
        payments: [PaymentEntry],
        incomeOccurrences: [IncomeOccurrence] = [],
        from startMonth: DateComponents,
        to endMonth: DateComponents,
        referenceDate: Date,
        calendar: Calendar
    ) -> [CalendarMonthSection] {
        guard let _ = startMonth.year, let _ = startMonth.month else { return [] }
        guard let _ = endMonth.year, let _ = endMonth.month else { return [] }

        let startOfToday = calendar.startOfDay(for: referenceDate)
        let traceID = String(UUID().uuidString.prefix(8))
        Logger.log(
            "[CalendarSectionsBuilder][\(traceID)] build start: startMonth=\(Self.sectionId(from: startMonth)) endMonth=\(Self.sectionId(from: endMonth)) today=\(startOfToday.ISO8601Format()) occurrences=\(occurrences.count) incomeOccurrences=\(incomeOccurrences.count) payments=\(payments.count)",
            level: .debug
        )

        var paymentsByOccurrence: [CalendarPaymentKey: [PaymentEntry]] = [:]
        paymentsByOccurrence.reserveCapacity(payments.count)
        for payment in payments {
            guard let billID = payment.bill?.persistentModelID else { continue }
            let occurrenceDay = calendar.startOfDay(for: payment.occurrenceDate)
            let key = CalendarPaymentKey(billID: billID, occurrenceDay: occurrenceDay)
            paymentsByOccurrence[key, default: []].append(payment)
        }
        let paymentKeyCount = paymentsByOccurrence.count
        let paymentKeysWithMultiple = paymentsByOccurrence.values.filter { $0.count > 1 }.count
        Logger.log(
            "[CalendarSectionsBuilder][\(traceID)] grouped payments: keys=\(paymentKeyCount) keysWithMultiplePayments=\(paymentKeysWithMultiple)",
            level: .debug
        )

        let occurrenceKeySet: Set<CalendarPaymentKey> = Set(
            occurrences.map { occurrence in
                CalendarPaymentKey(
                    billID: occurrence.bill.persistentModelID,
                    occurrenceDay: calendar.startOfDay(for: occurrence.dueDate)
                )
            }
        )

        let unmatchedPaymentKeys = paymentsByOccurrence.keys.filter { !occurrenceKeySet.contains($0) }
        if !unmatchedPaymentKeys.isEmpty {
            Logger.log(
                "[CalendarSectionsBuilder][\(traceID)] WARNING: unmatched payment keys=\(unmatchedPaymentKeys.count) (payment.occurrenceDate doesn't match any generated occurrence day in this range)",
                level: .warning
            )

            if isVerboseTraceEnabled {
                for key in unmatchedPaymentKeys.prefix(5) {
                    let examplePayment = paymentsByOccurrence[key]?.first
                    let billName = examplePayment?.bill?.name ?? "unknown"
                    let occurrenceDate = examplePayment?.occurrenceDate.ISO8601Format() ?? "nil"
                    let datePaid = examplePayment?.datePaid.ISO8601Format() ?? "nil"

                    Logger.log(
                        "[CalendarSectionsBuilder][\(traceID)] unmatched key: bill='\(billName)' keyDay=\(key.occurrenceDay.ISO8601Format()) payment.occurrenceDate=\(occurrenceDate) payment.datePaid=\(datePaid)",
                        level: .warning
                    )
                }
            }
        }

        var sections: [CalendarMonthSection] = []
        var current = startMonth

        while !isAfter(current, endMonth, calendar: calendar) {
            guard let monthStart = calendar.date(from: current),
                  let monthInterval = calendar.dateInterval(of: .month, for: monthStart) else {
                break
            }

            let monthOccurrences = occurrences.filter { contains($0.dueDate, in: monthInterval) }
            let monthIncomes = incomeOccurrences.filter { contains($0.date, in: monthInterval) }
            let monthPayments = payments.filter { contains($0.datePaid, in: monthInterval) }
            Logger.log(
                "[CalendarSectionsBuilder][\(traceID)] month=\(Self.sectionId(from: current)) intervalStart=\(monthInterval.start.ISO8601Format()) intervalEnd=\(monthInterval.end.ISO8601Format()) occurrences=\(monthOccurrences.count) incomes=\(monthIncomes.count) payments=\(monthPayments.count)",
                level: .debug
            )

            var items: [CalendarListItem] = []
            items.append(contentsOf: monthIncomes.map { .income($0) })

            if isVerboseTraceEnabled, !monthIncomes.isEmpty {
                for incomeOccurrence in monthIncomes {
                    Logger.log(
                        "[CalendarSectionsBuilder][\(traceID)] month=\(Self.sectionId(from: current)) income '\(incomeOccurrence.name)' date=\(incomeOccurrence.date.ISO8601Format()) amount=\(incomeOccurrence.amount)",
                        level: .debug
                    )
                }
            }

            var producedBills = 0
            var skippedFullyPaid = 0

            for occurrence in monthOccurrences {
                let startOfDueDate = calendar.startOfDay(for: occurrence.dueDate)

                let key = CalendarPaymentKey(billID: occurrence.bill.persistentModelID, occurrenceDay: startOfDueDate)
                let occurrencePayments = paymentsByOccurrence[key] ?? []
                let totalPaid = occurrencePayments.reduce(Decimal.zero) { $0 + $1.amount }

                // Fully paid → skip (only the payment on datePaid represents this bill)
                if totalPaid >= occurrence.amount {
                    skippedFullyPaid += 1
                    if isVerboseTraceEnabled {
                        Logger.log(
                            "[CalendarSectionsBuilder][\(traceID)] month=\(Self.sectionId(from: current)) bill '\(occurrence.name)' due=\(occurrence.dueDate.ISO8601Format()) SKIPPED (fully paid, totalPaid=\(totalPaid))",
                            level: .debug
                        )
                    }
                    continue
                }

                let status: BillDueStatus
                if totalPaid > 0 {
                    status = .partiallyPaid(paid: totalPaid, remaining: occurrence.amount - totalPaid)
                } else if startOfDueDate < startOfToday {
                    status = .missed
                } else {
                    status = .upcoming
                }

                let display = BillDisplay(occurrence: occurrence, status: status)
                items.append(.bill(display))
                producedBills += 1

                if isVerboseTraceEnabled {
                    Logger.log(
                        "[CalendarSectionsBuilder][\(traceID)] month=\(Self.sectionId(from: current)) bill '\(occurrence.name)' due=\(occurrence.dueDate.ISO8601Format()) status=\(status) payments=\(occurrencePayments.count)",
                        level: .debug
                    )
                }
            }

            // Add payments to list items
            items.append(contentsOf: monthPayments.map { .payment($0) })

            // Sort by date first, then by type (income -> bills/payments -> divider -> empty), then by id for stability
            items.sort { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date < rhs.date
                }
                if lhs.typeSortOrder != rhs.typeSortOrder {
                    return lhs.typeSortOrder < rhs.typeSortOrder
                }
                return lhs.id < rhs.id
            }
            Logger.log(
                "[CalendarSectionsBuilder][\(traceID)] month=\(Self.sectionId(from: current)) items after sort: total=\(items.count) income=\(monthIncomes.count) bills=\(producedBills) payments=\(monthPayments.count) skippedFullyPaid=\(skippedFullyPaid)",
                level: .debug
            )

            let sectionId = Self.sectionId(from: current)
            if items.isEmpty {
                items = [.emptyMonth(sectionId: sectionId)]
                Logger.log(
                    "[CalendarSectionsBuilder][\(traceID)] month=\(sectionId) inserted emptyMonth item",
                    level: .debug
                )
            }

            if !items.isEmpty, items.first?.isEmptyMonth != true, contains(startOfToday, in: monthInterval) {
                let insertionIndex = items.firstIndex(where: { item in
                    calendar.startOfDay(for: item.date) >= startOfToday
                }) ?? items.count

                items.insert(.todayDivider(date: startOfToday, sectionId: sectionId), at: insertionIndex)
                Logger.log(
                    "[CalendarSectionsBuilder][\(traceID)] month=\(sectionId) inserted todayDivider at index=\(insertionIndex) today=\(startOfToday.ISO8601Format())",
                    level: .debug
                )
            }

            // Calculate totals — only non-fully-paid bills count toward totalBillsDue
            let totalIncome = monthIncomes.reduce(Decimal.zero) { $0 + $1.amount }
            let totalBillsDue = monthOccurrences.reduce(Decimal.zero) { partial, occurrence in
                let startOfDueDate = calendar.startOfDay(for: occurrence.dueDate)
                let key = CalendarPaymentKey(billID: occurrence.bill.persistentModelID, occurrenceDay: startOfDueDate)
                let occurrencePayments = paymentsByOccurrence[key] ?? []
                let totalPaid = occurrencePayments.reduce(Decimal.zero) { $0 + $1.amount }

                if totalPaid >= occurrence.amount { return partial }
                if totalPaid > 0 { return partial + (occurrence.amount - totalPaid) }
                return partial + occurrence.amount
            }

            // A month is "past" once its last day is strictly before today (i.e. the
            // exclusive month-end <= startOfToday). Past months populate totalPaid with
            // actual payments made in the month (rendered in paid-green); totalBillsDue
            // continues to mean still-outstanding amount (rendered in red).
            let isPastMonth = monthInterval.end <= startOfToday
            let totalPaid: Decimal = isPastMonth
                ? monthPayments.reduce(Decimal.zero) { $0 + $1.amount }
                : 0

            Logger.log(
                "[CalendarSectionsBuilder][\(traceID)] month=\(sectionId) totals: totalIncome=\(totalIncome) totalPaid=\(totalPaid) totalBillsDue=\(totalBillsDue) isPast=\(isPastMonth)",
                level: .debug
            )

            sections.append(
                CalendarMonthSection(
                    id: sectionId,
                    title: monthStart.formatted(.dateTime.month(.wide).year()),
                    items: items,
                    totalIncome: totalIncome,
                    totalBillsDue: totalBillsDue,
                    totalPaid: totalPaid,
                    isPast: isPastMonth
                )
            )

            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else { break }
            current = calendar.dateComponents([.year, .month], from: nextMonth)
        }

        Logger.log(
            "[CalendarSectionsBuilder][\(traceID)] build end: sections=\(sections.count)",
            level: .debug
        )
        return sections
    }

    private static func isAfter(
        _ lhs: DateComponents,
        _ rhs: DateComponents,
        calendar: Calendar
    ) -> Bool {
        guard let lhsDate = calendar.date(from: lhs), let rhsDate = calendar.date(from: rhs) else {
            return false
        }
        return lhsDate > rhsDate
    }

    private static func sectionId(from components: DateComponents) -> String {
        let year = components.year ?? 0
        let month = components.month ?? 0
        return String(format: "%04d-%02d", year, month)
    }

    private static func contains(_ date: Date, in interval: DateInterval) -> Bool {
        date >= interval.start && date < interval.end
    }
}
