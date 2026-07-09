//
//  ScreenshotMockData.swift
//  Billo
//
//  Created by Jiri Urbasek on 7/9/26.
//

#if SCREENSHOTS
import Foundation
import SwiftData
import UserNotifications

/// Seeds the in-memory store used by the `BilloScreenshots` scheme with
/// realistic US-market data: ~3 months of fully paid history plus a mix of
/// upcoming bills and incomes. All dates are relative to the launch date so
/// screenshots always look current.
@MainActor
enum ScreenshotMockData {
    private struct BillSpec {
        let name: String
        let amount: Decimal
        let dayOfMonth: Int
        let category: DefaultCategoryIdentifier
        var accountIdentifier: String? = nil
        var providerURL: String? = nil
    }

    /// Monthly household bills for a typical US renter/homeowner mix, spread
    /// across the month so both "due soon" and "later this month" sections
    /// have content no matter which day the screenshots are taken.
    private static let monthlyBills: [BillSpec] = [
        BillSpec(name: "Mortgage", amount: 2150, dayOfMonth: 1, category: .housing, accountIdentifier: "••••4821"),
        BillSpec(name: "Netflix", amount: 15.49, dayOfMonth: 3, category: .subscriptions, providerURL: "https://www.netflix.com"),
        BillSpec(name: "Internet — Xfinity", amount: 79.99, dayOfMonth: 5, category: .utilities, accountIdentifier: "••••7302", providerURL: "https://www.xfinity.com"),
        BillSpec(name: "Car Payment", amount: 389, dayOfMonth: 8, category: .loans, accountIdentifier: "••••9917"),
        BillSpec(name: "Spotify Premium", amount: 11.99, dayOfMonth: 9, category: .subscriptions),
        BillSpec(name: "Cell Phone — Verizon", amount: 92, dayOfMonth: 12, category: .utilities, providerURL: "https://www.verizon.com"),
        BillSpec(name: "Electric Bill", amount: 128.40, dayOfMonth: 15, category: .utilities, accountIdentifier: "••••2276"),
        BillSpec(name: "Water & Sewer", amount: 64.50, dayOfMonth: 18, category: .utilities),
        BillSpec(name: "Car Insurance — GEICO", amount: 148.25, dayOfMonth: 20, category: .insurance, providerURL: "https://www.geico.com"),
        BillSpec(name: "Gym — Planet Fitness", amount: 24.99, dayOfMonth: 22, category: .subscriptions),
        BillSpec(name: "Student Loan", amount: 216, dayOfMonth: 25, category: .loans, accountIdentifier: "••••5540"),
        BillSpec(name: "Renters Insurance", amount: 21.50, dayOfMonth: 27, category: .insurance)
    ]

    static func seed(into context: ModelContext) {
        let calendar = Calendar.current
        let referenceDate = Date()
        let todayStart = calendar.startOfDay(for: referenceDate)

        // Monthly bills anchored 3 months back so history is fully populated.
        for (index, spec) in monthlyBills.enumerated() {
            let rule = RecurrenceRule(
                pattern: .monthly,
                frequency: 1,
                dayOfWeek: nil,
                dayOfMonth: spec.dayOfMonth,
                endConditionType: .never,
                endDate: nil
            )
            let bill = Bill(
                name: spec.name,
                amount: spec.amount,
                currencyCode: "USD",
                dueDate: day(spec.dayOfMonth, monthOffset: -3, relativeTo: referenceDate, calendar: calendar),
                accountIdentifier: spec.accountIdentifier,
                providerURL: spec.providerURL,
                categoryIdentifier: .predefined(spec.category),
                recurrenceRule: rule
            )
            context.insert(bill)
            payPastOccurrences(of: bill, before: todayStart, billIndex: index, now: referenceDate, in: context, calendar: calendar)
        }

        // A yearly bill anchored one year back: its renewal lands in the
        // current month, so a yearly cadence shows up alongside the monthly ones.
        let primeRule = RecurrenceRule(
            pattern: .yearly,
            frequency: 1,
            dayOfWeek: nil,
            dayOfMonth: nil,
            endConditionType: .never,
            endDate: nil
        )
        let prime = Bill(
            name: "Amazon Prime",
            amount: 139,
            currencyCode: "USD",
            dueDate: day(20, monthOffset: -12, relativeTo: referenceDate, calendar: calendar),
            providerURL: "https://www.amazon.com",
            categoryIdentifier: .predefined(.subscriptions),
            recurrenceRule: primeRule
        )
        context.insert(prime)
        payPastOccurrences(of: prime, before: todayStart, billIndex: monthlyBills.count, now: referenceDate, in: context, calendar: calendar)

        // Incomes: a bi-weekly paycheck (the most common US pay cadence) plus
        // a monthly side gig. Past occurrences are materialized automatically
        // by BillsModel.refresh() at startup.
        let paycheckRule = RecurrenceRule(
            pattern: .weekly,
            frequency: 2,
            dayOfWeek: .friday,
            dayOfMonth: nil,
            endConditionType: .never,
            endDate: nil
        )
        let paycheckAnchor = calendar.date(
            byAdding: .day,
            value: -84,
            to: previousFriday(onOrBefore: referenceDate, calendar: calendar)
        ) ?? referenceDate
        let paycheck = Income(
            name: "Paycheck",
            amount: 2485,
            currencyCode: "USD",
            startDate: paycheckAnchor,
            recurrenceRule: paycheckRule
        )
        context.insert(paycheck)

        let freelanceRule = RecurrenceRule(
            pattern: .monthly,
            frequency: 1,
            dayOfWeek: nil,
            dayOfMonth: 28,
            endConditionType: .never,
            endDate: nil
        )
        let freelance = Income(
            name: "Freelance Design",
            amount: 850,
            currencyCode: "USD",
            startDate: day(28, monthOffset: -3, relativeTo: referenceDate, calendar: calendar),
            recurrenceRule: freelanceRule
        )
        context.insert(freelance)

        // A persisted currency skips both the onboarding flow and the
        // currency picker, landing screenshots directly on the main UI.
        context.insert(AppSettings(currencyCode: "USD"))

        do {
            try context.save()
        } catch {
            Logger.log("Failed to seed screenshot data: \(error)", level: .error)
        }
    }

    // MARK: - Payments

    /// Marks every occurrence strictly before `endDate` as paid in full, with
    /// payment dates staggered a day or two around each due date so the
    /// history reads as organic rather than machine-generated.
    private static func payPastOccurrences(
        of bill: Bill,
        before endDate: Date,
        billIndex: Int,
        now: Date,
        in context: ModelContext,
        calendar: Calendar
    ) {
        let occurrences: [Date]
        if let rule = bill.recurrenceRule {
            occurrences = rule.generateOccurrences(from: bill.dueDate, until: endDate, calendar: calendar)
        } else {
            occurrences = bill.dueDate < endDate ? [bill.dueDate] : []
        }

        let paidDayOffsets = [-1, 0, -2, 1, 0]
        for (occurrenceIndex, dueDate) in occurrences.enumerated() {
            let issued = IssuedOccurrence(
                occurrenceKey: bill.occurrenceKey(for: dueDate),
                dueDate: dueDate,
                billName: bill.name,
                billAmount: bill.amount,
                billCurrencyCode: bill.currencyCode,
                billAccountIdentifier: bill.accountIdentifier,
                billNotes: bill.notes,
                billCategoryRawValue: bill.categoryIdentifier?.rawValue,
                bill: bill
            )
            context.insert(issued)

            let offset = paidDayOffsets[(billIndex + occurrenceIndex) % paidDayOffsets.count]
            let paidDate = min(calendar.date(byAdding: .day, value: offset, to: dueDate) ?? dueDate, now)
            let payment = PaymentEntry(
                amount: bill.amount,
                datePaid: paidDate,
                confirmationNumber: nil,
                issuedOccurrence: issued
            )
            context.insert(payment)
        }
    }

    // MARK: - Date helpers

    /// Returns the given day of the month in the month `monthOffset` months
    /// away from `referenceDate` (e.g. `day(15, monthOffset: -3)` = the 15th
    /// three months ago).
    private static func day(
        _ day: Int,
        monthOffset: Int,
        relativeTo referenceDate: Date,
        calendar: Calendar
    ) -> Date {
        let base = calendar.date(byAdding: .month, value: monthOffset, to: referenceDate) ?? referenceDate
        let components = calendar.dateComponents([.year, .month], from: base)
        let monthStart = calendar.date(from: components) ?? base
        return calendar.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart
    }

    private static func previousFriday(onOrBefore date: Date, calendar: Calendar) -> Date {
        var candidate = calendar.startOfDay(for: date)
        while calendar.component(.weekday, from: candidate) != 6 {
            candidate = calendar.date(byAdding: .day, value: -1, to: candidate) ?? candidate
        }
        return candidate
    }
}

/// Pretends notifications are authorized while doing nothing, so screenshot
/// runs never trigger permission prompts, banners, or scheduled notifications.
struct ScreenshotNoopNotificationCenter: UNNotificationCenterProtocol {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }
    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    func add(_ request: UNNotificationRequest) async throws {}
    func pendingNotificationRequests() async -> [UNNotificationRequest] { [] }
    func removePendingNotificationRequests(withIdentifiers: [String]) {}
    func removeAllPendingNotificationRequests() {}
    func setBadgeCount(_ count: Int) async throws {}
}
#endif
