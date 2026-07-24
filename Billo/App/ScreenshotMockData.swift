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
/// realistic market data: ~3 months of fully paid history plus a mix of
/// upcoming bills and incomes. All dates are relative to the launch date so
/// screenshots always look current.
///
/// The dataset is market-aware for localized screenshots: set the
/// `SCREENSHOT_MARKET` environment variable (`us`, `it`, `es`, `mx`) on the
/// scheme, or just set the run's App Region (Italy/Spain/Mexico) — the region
/// is the fallback signal. Defaults to the US dataset.
@MainActor
enum ScreenshotMockData {
    // MARK: - Markets

    enum Market: String {
        case us, it, es, mx, br

        static var current: Market {
            if let raw = ProcessInfo.processInfo.environment["SCREENSHOT_MARKET"],
               let market = Market(rawValue: raw.lowercased()) {
                return market
            }
            switch Locale.current.region?.identifier {
            case "IT": return .it
            case "ES": return .es
            case "MX": return .mx
            case "BR": return .br
            default: return .us
            }
        }
    }

    private struct BillSpec {
        let name: String
        let amount: Decimal
        let dayOfMonth: Int
        let category: DefaultCategoryIdentifier
        var accountIdentifier: String? = nil
        var providerURL: String? = nil
    }

    private struct IncomeSpec {
        enum Cadence {
            /// Every second Friday — the common US pay cadence; also stands in
            /// for the Mexican quincena.
            case biweeklyFriday
            case monthly(dayOfMonth: Int)
        }

        let name: String
        let amount: Decimal
        let cadence: Cadence
    }

    private struct MarketDataset {
        let currencyCode: String
        /// Spread across the month so both "due soon" and "later this month"
        /// sections have content no matter which day the screenshots are taken.
        let monthlyBills: [BillSpec]
        /// Anchored one year back: its renewal lands in the current month, so
        /// a yearly cadence shows up alongside the monthly ones.
        let yearlyBill: BillSpec
        let primaryIncome: IncomeSpec
        let sideIncome: IncomeSpec
    }

    // MARK: - Datasets

    /// Typical US renter/homeowner mix.
    private static let usDataset = MarketDataset(
        currencyCode: "USD",
        monthlyBills: [
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
        ],
        yearlyBill: BillSpec(name: "Amazon Prime", amount: 139, dayOfMonth: 20, category: .subscriptions, providerURL: "https://www.amazon.com"),
        primaryIncome: IncomeSpec(name: "Paycheck", amount: 2485, cadence: .biweeklyFriday),
        sideIncome: IncomeSpec(name: "Freelance Design", amount: 850, cadence: .monthly(dayOfMonth: 28))
    )

    /// Italian household: monthly stipendio, local utility/insurance brands.
    private static let itDataset = MarketDataset(
        currencyCode: "EUR",
        monthlyBills: [
            BillSpec(name: "Mutuo casa", amount: 850, dayOfMonth: 1, category: .housing, accountIdentifier: "••••4821"),
            BillSpec(name: "Netflix", amount: 13.99, dayOfMonth: 3, category: .subscriptions, providerURL: "https://www.netflix.com"),
            BillSpec(name: "Internet — Fastweb", amount: 29.95, dayOfMonth: 5, category: .utilities, accountIdentifier: "••••7302", providerURL: "https://www.fastweb.it"),
            BillSpec(name: "Rata auto", amount: 260, dayOfMonth: 8, category: .loans, accountIdentifier: "••••9917"),
            BillSpec(name: "Spotify Premium", amount: 10.99, dayOfMonth: 9, category: .subscriptions),
            BillSpec(name: "Cellulare — TIM", amount: 14.99, dayOfMonth: 12, category: .utilities, providerURL: "https://www.tim.it"),
            BillSpec(name: "Bolletta luce — Enel", amount: 96.40, dayOfMonth: 15, category: .utilities, accountIdentifier: "••••2276", providerURL: "https://www.enel.it"),
            BillSpec(name: "Acqua", amount: 38.50, dayOfMonth: 18, category: .utilities),
            BillSpec(name: "RC auto — Generali", amount: 54.20, dayOfMonth: 20, category: .insurance, providerURL: "https://www.generali.it"),
            BillSpec(name: "Palestra", amount: 39.90, dayOfMonth: 22, category: .subscriptions),
            BillSpec(name: "Prestito personale", amount: 180, dayOfMonth: 25, category: .loans, accountIdentifier: "••••5540"),
            BillSpec(name: "Assicurazione casa", amount: 15.50, dayOfMonth: 27, category: .insurance)
        ],
        yearlyBill: BillSpec(name: "Amazon Prime", amount: 49.90, dayOfMonth: 20, category: .subscriptions, providerURL: "https://www.amazon.it"),
        primaryIncome: IncomeSpec(name: "Stipendio", amount: 1780, cadence: .monthly(dayOfMonth: 27)),
        sideIncome: IncomeSpec(name: "Lavoro freelance", amount: 600, cadence: .monthly(dayOfMonth: 10))
    )

    /// Spanish household: nómina at month end, recibos vocabulary.
    private static let esDataset = MarketDataset(
        currencyCode: "EUR",
        monthlyBills: [
            BillSpec(name: "Hipoteca", amount: 780, dayOfMonth: 1, category: .housing, accountIdentifier: "••••4821"),
            BillSpec(name: "Netflix", amount: 13.99, dayOfMonth: 3, category: .subscriptions, providerURL: "https://www.netflix.com"),
            BillSpec(name: "Internet — Movistar", amount: 42, dayOfMonth: 5, category: .utilities, accountIdentifier: "••••7302", providerURL: "https://www.movistar.es"),
            BillSpec(name: "Cuota del coche", amount: 245, dayOfMonth: 8, category: .loans, accountIdentifier: "••••9917"),
            BillSpec(name: "Spotify Premium", amount: 10.99, dayOfMonth: 9, category: .subscriptions),
            BillSpec(name: "Móvil — Vodafone", amount: 22, dayOfMonth: 12, category: .utilities, providerURL: "https://www.vodafone.es"),
            BillSpec(name: "Recibo de luz — Iberdrola", amount: 88.30, dayOfMonth: 15, category: .utilities, accountIdentifier: "••••2276", providerURL: "https://www.iberdrola.es"),
            BillSpec(name: "Agua", amount: 36.50, dayOfMonth: 18, category: .utilities),
            BillSpec(name: "Seguro del coche — Mapfre", amount: 58.75, dayOfMonth: 20, category: .insurance, providerURL: "https://www.mapfre.es"),
            BillSpec(name: "Gimnasio", amount: 34.90, dayOfMonth: 22, category: .subscriptions),
            BillSpec(name: "Préstamo personal", amount: 160, dayOfMonth: 25, category: .loans, accountIdentifier: "••••5540"),
            BillSpec(name: "Seguro de hogar", amount: 17.50, dayOfMonth: 27, category: .insurance)
        ],
        yearlyBill: BillSpec(name: "Amazon Prime", amount: 49.90, dayOfMonth: 20, category: .subscriptions, providerURL: "https://www.amazon.es"),
        primaryIncome: IncomeSpec(name: "Nómina", amount: 1650, cadence: .monthly(dayOfMonth: 28)),
        sideIncome: IncomeSpec(name: "Trabajo freelance", amount: 520, cadence: .monthly(dayOfMonth: 12))
    )

    /// Mexican household: quincena-style pay, MXN amounts, local brands.
    private static let mxDataset = MarketDataset(
        currencyCode: "MXN",
        monthlyBills: [
            BillSpec(name: "Renta", amount: 9500, dayOfMonth: 1, category: .housing, accountIdentifier: "••••4821"),
            BillSpec(name: "Netflix", amount: 219, dayOfMonth: 3, category: .subscriptions, providerURL: "https://www.netflix.com"),
            BillSpec(name: "Internet — Telmex", amount: 599, dayOfMonth: 5, category: .utilities, accountIdentifier: "••••7302", providerURL: "https://www.telmex.com"),
            BillSpec(name: "Pago del auto", amount: 4350, dayOfMonth: 8, category: .loans, accountIdentifier: "••••9917"),
            BillSpec(name: "Spotify Premium", amount: 129, dayOfMonth: 9, category: .subscriptions),
            BillSpec(name: "Celular — Telcel", amount: 399, dayOfMonth: 12, category: .utilities, providerURL: "https://www.telcel.com"),
            BillSpec(name: "Luz — CFE", amount: 875, dayOfMonth: 15, category: .utilities, accountIdentifier: "••••2276", providerURL: "https://www.cfe.mx"),
            BillSpec(name: "Agua", amount: 320, dayOfMonth: 18, category: .utilities),
            BillSpec(name: "Seguro del auto — GNP", amount: 1150, dayOfMonth: 20, category: .insurance, providerURL: "https://www.gnp.com.mx"),
            BillSpec(name: "Gimnasio — Smart Fit", amount: 599, dayOfMonth: 22, category: .subscriptions),
            BillSpec(name: "Préstamo personal", amount: 1800, dayOfMonth: 25, category: .loans, accountIdentifier: "••••5540"),
            BillSpec(name: "Seguro de gastos médicos", amount: 950, dayOfMonth: 27, category: .insurance)
        ],
        yearlyBill: BillSpec(name: "Amazon Prime", amount: 899, dayOfMonth: 20, category: .subscriptions, providerURL: "https://www.amazon.com.mx"),
        primaryIncome: IncomeSpec(name: "Nómina", amount: 8200, cadence: .biweeklyFriday),
        sideIncome: IncomeSpec(name: "Freelance", amount: 3500, cadence: .monthly(dayOfMonth: 28))
    )

    /// Brazilian household: boleto culture (manually paid slips), monthly
    /// salário, BRL amounts, local brands.
    private static let brDataset = MarketDataset(
        currencyCode: "BRL",
        monthlyBills: [
            BillSpec(name: "Aluguel", amount: 1800, dayOfMonth: 1, category: .housing, accountIdentifier: "••••4821"),
            BillSpec(name: "Netflix", amount: 44.90, dayOfMonth: 3, category: .subscriptions, providerURL: "https://www.netflix.com"),
            BillSpec(name: "Internet — Vivo Fibra", amount: 119.90, dayOfMonth: 5, category: .utilities, accountIdentifier: "••••7302", providerURL: "https://www.vivo.com.br"),
            BillSpec(name: "Financiamento do carro", amount: 890, dayOfMonth: 8, category: .loans, accountIdentifier: "••••9917"),
            BillSpec(name: "Spotify Premium", amount: 21.90, dayOfMonth: 9, category: .subscriptions),
            BillSpec(name: "Celular — Claro", amount: 59.90, dayOfMonth: 12, category: .utilities, providerURL: "https://www.claro.com.br"),
            BillSpec(name: "Conta de luz — Enel", amount: 245, dayOfMonth: 15, category: .utilities, accountIdentifier: "••••2276", providerURL: "https://www.enel.com.br"),
            BillSpec(name: "Água — Sabesp", amount: 98, dayOfMonth: 18, category: .utilities, providerURL: "https://www.sabesp.com.br"),
            BillSpec(name: "Seguro do carro — Porto Seguro", amount: 185, dayOfMonth: 20, category: .insurance, providerURL: "https://www.portoseguro.com.br"),
            BillSpec(name: "Academia — Smart Fit", amount: 129.90, dayOfMonth: 22, category: .subscriptions),
            BillSpec(name: "Empréstimo pessoal", amount: 350, dayOfMonth: 25, category: .loans, accountIdentifier: "••••5540"),
            BillSpec(name: "Plano de saúde", amount: 480, dayOfMonth: 27, category: .insurance)
        ],
        yearlyBill: BillSpec(name: "Amazon Prime", amount: 166.80, dayOfMonth: 20, category: .subscriptions, providerURL: "https://www.amazon.com.br"),
        primaryIncome: IncomeSpec(name: "Salário", amount: 4200, cadence: .monthly(dayOfMonth: 5)),
        sideIncome: IncomeSpec(name: "Freelance", amount: 1200, cadence: .monthly(dayOfMonth: 20))
    )

    private static func dataset(for market: Market) -> MarketDataset {
        switch market {
        case .us: usDataset
        case .it: itDataset
        case .es: esDataset
        case .mx: mxDataset
        case .br: brDataset
        }
    }

    // MARK: - Seeding

    static func seed(into context: ModelContext) {
        let dataset = dataset(for: .current)
        let calendar = Calendar.current
        let referenceDate = Date()
        let todayStart = calendar.startOfDay(for: referenceDate)

        // Monthly bills anchored 3 months back so history is fully populated.
        for (index, spec) in dataset.monthlyBills.enumerated() {
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
                currencyCode: dataset.currencyCode,
                dueDate: day(spec.dayOfMonth, monthOffset: -3, relativeTo: referenceDate, calendar: calendar),
                accountIdentifier: spec.accountIdentifier,
                providerURL: spec.providerURL,
                categoryIdentifier: .predefined(spec.category),
                recurrenceRule: rule
            )
            context.insert(bill)
            payPastOccurrences(of: bill, before: todayStart, billIndex: index, now: referenceDate, in: context, calendar: calendar)
        }

        let yearlyRule = RecurrenceRule(
            pattern: .yearly,
            frequency: 1,
            dayOfWeek: nil,
            dayOfMonth: nil,
            endConditionType: .never,
            endDate: nil
        )
        let yearly = Bill(
            name: dataset.yearlyBill.name,
            amount: dataset.yearlyBill.amount,
            currencyCode: dataset.currencyCode,
            dueDate: day(dataset.yearlyBill.dayOfMonth, monthOffset: -12, relativeTo: referenceDate, calendar: calendar),
            accountIdentifier: dataset.yearlyBill.accountIdentifier,
            providerURL: dataset.yearlyBill.providerURL,
            categoryIdentifier: .predefined(dataset.yearlyBill.category),
            recurrenceRule: yearlyRule
        )
        context.insert(yearly)
        payPastOccurrences(of: yearly, before: todayStart, billIndex: dataset.monthlyBills.count, now: referenceDate, in: context, calendar: calendar)

        // Past income occurrences are materialized automatically by
        // BillsModel.refresh() at startup.
        for spec in [dataset.primaryIncome, dataset.sideIncome] {
            context.insert(income(from: spec, currencyCode: dataset.currencyCode, referenceDate: referenceDate, calendar: calendar))
        }

        // A persisted currency skips both the onboarding flow and the
        // currency picker, landing screenshots directly on the main UI.
        context.insert(AppSettings(currencyCode: dataset.currencyCode))

        do {
            try context.save()
        } catch {
            Logger.log("Failed to seed screenshot data: \(error)", level: .error)
        }
    }

    private static func income(
        from spec: IncomeSpec,
        currencyCode: String,
        referenceDate: Date,
        calendar: Calendar
    ) -> Income {
        let rule: RecurrenceRule
        let startDate: Date
        switch spec.cadence {
        case .biweeklyFriday:
            rule = RecurrenceRule(
                pattern: .weekly,
                frequency: 2,
                dayOfWeek: .friday,
                dayOfMonth: nil,
                endConditionType: .never,
                endDate: nil
            )
            startDate = calendar.date(
                byAdding: .day,
                value: -84,
                to: previousFriday(onOrBefore: referenceDate, calendar: calendar)
            ) ?? referenceDate
        case .monthly(let dayOfMonth):
            rule = RecurrenceRule(
                pattern: .monthly,
                frequency: 1,
                dayOfWeek: nil,
                dayOfMonth: dayOfMonth,
                endConditionType: .never,
                endDate: nil
            )
            startDate = day(dayOfMonth, monthOffset: -3, relativeTo: referenceDate, calendar: calendar)
        }
        return Income(
            name: spec.name,
            amount: spec.amount,
            currencyCode: currencyCode,
            startDate: startDate,
            recurrenceRule: rule
        )
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
