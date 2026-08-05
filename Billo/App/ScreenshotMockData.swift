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
/// upcoming bills and incomes.
///
/// Every bill is anchored to the launch date via `dueInDays` offsets, so the
/// bills list renders the SAME shape on any capture date: exactly one bill
/// due today (offset 0), two inside the next 7 days (3, 6), and the rest
/// spread across the next 30 days. Screenshots stay evergreen AND
/// structurally identical run to run.
///
/// The dataset is market-aware for localized screenshots: set the
/// `SCREENSHOT_MARKET` environment variable (`us`, `it`, `es`, `mx`, `br`) on
/// the scheme, or just set the run's App Region (Italy/Spain/Mexico/Brazil) —
/// the region is the fallback signal. Defaults to the US dataset.
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

    /// The shared due-date offset spread, in days from the capture date.
    /// Index-aligned with every market's `monthlyBills` array so row order —
    /// and therefore capture click coordinates — hold across markets:
    /// one bill today (0), two in the next 7 days (3, 6), the rest across
    /// the next 30 days (9…30).
    private static let dueInDaysSpread = [0, 3, 6, 9, 11, 13, 16, 18, 23, 25, 27, 30]

    private struct BillSpec {
        let name: String
        let amount: Decimal
        /// Days from the capture date to the bill's next due date.
        let dueInDays: Int
        let category: DefaultCategoryIdentifier
        var accountIdentifier: String? = nil
        var providerURL: String? = nil
    }

    private struct IncomeSpec {
        enum Cadence {
            /// Every second Friday — the common US pay cadence; also stands in
            /// for the Mexican quincena.
            case biweeklyFriday
            /// Monthly, next occurrence `inDays` days from the capture date.
            case monthly(inDays: Int)
        }

        let name: String
        let amount: Decimal
        let cadence: Cadence
    }

    private struct MarketDataset {
        let currencyCode: String
        /// Ordered by `dueInDays` (the shared spread), soonest first.
        let monthlyBills: [BillSpec]
        /// Anchored one year back: its renewal lands within the next 30 days,
        /// so a yearly cadence shows up alongside the monthly ones.
        let yearlyBill: BillSpec
        let primaryIncome: IncomeSpec
        let sideIncome: IncomeSpec
    }

    // MARK: - Datasets

    /// Typical US renter/homeowner mix.
    private static let usDataset = MarketDataset(
        currencyCode: "USD",
        monthlyBills: [
            BillSpec(name: "Spotify Premium", amount: 11.99, dueInDays: 0, category: .subscriptions),
            BillSpec(name: "Cell Phone — Verizon", amount: 92, dueInDays: 3, category: .utilities, providerURL: "https://www.verizon.com"),
            BillSpec(name: "Electric Bill", amount: 128.40, dueInDays: 6, category: .utilities, accountIdentifier: "••••2276"),
            BillSpec(name: "Water & Sewer", amount: 64.50, dueInDays: 9, category: .utilities),
            BillSpec(name: "Car Insurance — GEICO", amount: 148.25, dueInDays: 11, category: .insurance, providerURL: "https://www.geico.com"),
            BillSpec(name: "Gym — Planet Fitness", amount: 24.99, dueInDays: 13, category: .subscriptions),
            BillSpec(name: "Student Loan", amount: 216, dueInDays: 16, category: .loans, accountIdentifier: "••••5540"),
            BillSpec(name: "Renters Insurance", amount: 21.50, dueInDays: 18, category: .insurance),
            BillSpec(name: "Mortgage", amount: 2150, dueInDays: 23, category: .housing, accountIdentifier: "••••4821"),
            BillSpec(name: "Netflix", amount: 15.49, dueInDays: 25, category: .subscriptions, providerURL: "https://www.netflix.com"),
            BillSpec(name: "Internet — Xfinity", amount: 79.99, dueInDays: 27, category: .utilities, accountIdentifier: "••••7302", providerURL: "https://www.xfinity.com"),
            BillSpec(name: "Car Payment", amount: 389, dueInDays: 30, category: .loans, accountIdentifier: "••••9917")
        ],
        yearlyBill: BillSpec(name: "Amazon Prime", amount: 139, dueInDays: 11, category: .subscriptions, providerURL: "https://www.amazon.com"),
        primaryIncome: IncomeSpec(name: "Paycheck", amount: 2485, cadence: .biweeklyFriday),
        sideIncome: IncomeSpec(name: "Freelance Design", amount: 850, cadence: .monthly(inDays: 19))
    )

    /// Italian household: monthly stipendio, local utility/insurance brands.
    private static let itDataset = MarketDataset(
        currencyCode: "EUR",
        monthlyBills: [
            BillSpec(name: "Spotify Premium", amount: 10.99, dueInDays: 0, category: .subscriptions),
            BillSpec(name: "Cellulare — TIM", amount: 14.99, dueInDays: 3, category: .utilities, providerURL: "https://www.tim.it"),
            BillSpec(name: "Bolletta luce — Enel", amount: 96.40, dueInDays: 6, category: .utilities, accountIdentifier: "••••2276", providerURL: "https://www.enel.it"),
            BillSpec(name: "Acqua", amount: 38.50, dueInDays: 9, category: .utilities),
            BillSpec(name: "RC auto — Generali", amount: 54.20, dueInDays: 11, category: .insurance, providerURL: "https://www.generali.it"),
            BillSpec(name: "Palestra", amount: 39.90, dueInDays: 13, category: .subscriptions),
            BillSpec(name: "Prestito personale", amount: 180, dueInDays: 16, category: .loans, accountIdentifier: "••••5540"),
            BillSpec(name: "Assicurazione casa", amount: 15.50, dueInDays: 18, category: .insurance),
            BillSpec(name: "Mutuo casa", amount: 850, dueInDays: 23, category: .housing, accountIdentifier: "••••4821"),
            BillSpec(name: "Netflix", amount: 13.99, dueInDays: 25, category: .subscriptions, providerURL: "https://www.netflix.com"),
            BillSpec(name: "Internet — Fastweb", amount: 29.95, dueInDays: 27, category: .utilities, accountIdentifier: "••••7302", providerURL: "https://www.fastweb.it"),
            BillSpec(name: "Rata auto", amount: 260, dueInDays: 30, category: .loans, accountIdentifier: "••••9917")
        ],
        yearlyBill: BillSpec(name: "Amazon Prime", amount: 49.90, dueInDays: 11, category: .subscriptions, providerURL: "https://www.amazon.it"),
        primaryIncome: IncomeSpec(name: "Stipendio", amount: 1780, cadence: .monthly(inDays: 18)),
        sideIncome: IncomeSpec(name: "Lavoro freelance", amount: 600, cadence: .monthly(inDays: 1))
    )

    /// Spanish household: nómina at month end, recibos vocabulary.
    private static let esDataset = MarketDataset(
        currencyCode: "EUR",
        monthlyBills: [
            BillSpec(name: "Spotify Premium", amount: 10.99, dueInDays: 0, category: .subscriptions),
            BillSpec(name: "Móvil — Vodafone", amount: 22, dueInDays: 3, category: .utilities, providerURL: "https://www.vodafone.es"),
            BillSpec(name: "Recibo de luz — Iberdrola", amount: 88.30, dueInDays: 6, category: .utilities, accountIdentifier: "••••2276", providerURL: "https://www.iberdrola.es"),
            BillSpec(name: "Agua", amount: 36.50, dueInDays: 9, category: .utilities),
            BillSpec(name: "Seguro del coche — Mapfre", amount: 58.75, dueInDays: 11, category: .insurance, providerURL: "https://www.mapfre.es"),
            BillSpec(name: "Gimnasio", amount: 34.90, dueInDays: 13, category: .subscriptions),
            BillSpec(name: "Préstamo personal", amount: 160, dueInDays: 16, category: .loans, accountIdentifier: "••••5540"),
            BillSpec(name: "Seguro de hogar", amount: 17.50, dueInDays: 18, category: .insurance),
            BillSpec(name: "Hipoteca", amount: 780, dueInDays: 23, category: .housing, accountIdentifier: "••••4821"),
            BillSpec(name: "Netflix", amount: 13.99, dueInDays: 25, category: .subscriptions, providerURL: "https://www.netflix.com"),
            BillSpec(name: "Internet — Movistar", amount: 42, dueInDays: 27, category: .utilities, accountIdentifier: "••••7302", providerURL: "https://www.movistar.es"),
            BillSpec(name: "Cuota del coche", amount: 245, dueInDays: 30, category: .loans, accountIdentifier: "••••9917")
        ],
        yearlyBill: BillSpec(name: "Amazon Prime", amount: 49.90, dueInDays: 11, category: .subscriptions, providerURL: "https://www.amazon.es"),
        primaryIncome: IncomeSpec(name: "Nómina", amount: 1650, cadence: .monthly(inDays: 19)),
        sideIncome: IncomeSpec(name: "Trabajo freelance", amount: 520, cadence: .monthly(inDays: 3))
    )

    /// Mexican household: quincena-style pay, MXN amounts, local brands.
    private static let mxDataset = MarketDataset(
        currencyCode: "MXN",
        monthlyBills: [
            BillSpec(name: "Spotify Premium", amount: 129, dueInDays: 0, category: .subscriptions),
            BillSpec(name: "Celular — Telcel", amount: 399, dueInDays: 3, category: .utilities, providerURL: "https://www.telcel.com"),
            BillSpec(name: "Luz — CFE", amount: 875, dueInDays: 6, category: .utilities, accountIdentifier: "••••2276", providerURL: "https://www.cfe.mx"),
            BillSpec(name: "Agua", amount: 320, dueInDays: 9, category: .utilities),
            BillSpec(name: "Seguro del auto — GNP", amount: 1150, dueInDays: 11, category: .insurance, providerURL: "https://www.gnp.com.mx"),
            BillSpec(name: "Gimnasio — Smart Fit", amount: 599, dueInDays: 13, category: .subscriptions),
            BillSpec(name: "Préstamo personal", amount: 1800, dueInDays: 16, category: .loans, accountIdentifier: "••••5540"),
            BillSpec(name: "Seguro de gastos médicos", amount: 950, dueInDays: 18, category: .insurance),
            BillSpec(name: "Renta", amount: 9500, dueInDays: 23, category: .housing, accountIdentifier: "••••4821"),
            BillSpec(name: "Netflix", amount: 219, dueInDays: 25, category: .subscriptions, providerURL: "https://www.netflix.com"),
            BillSpec(name: "Internet — Telmex", amount: 599, dueInDays: 27, category: .utilities, accountIdentifier: "••••7302", providerURL: "https://www.telmex.com"),
            BillSpec(name: "Pago del auto", amount: 4350, dueInDays: 30, category: .loans, accountIdentifier: "••••9917")
        ],
        yearlyBill: BillSpec(name: "Amazon Prime", amount: 899, dueInDays: 11, category: .subscriptions, providerURL: "https://www.amazon.com.mx"),
        primaryIncome: IncomeSpec(name: "Nómina", amount: 8200, cadence: .biweeklyFriday),
        sideIncome: IncomeSpec(name: "Freelance", amount: 3500, cadence: .monthly(inDays: 19))
    )

    /// Brazilian household: boleto culture (manually paid slips), monthly
    /// salário, BRL amounts, local brands.
    private static let brDataset = MarketDataset(
        currencyCode: "BRL",
        monthlyBills: [
            BillSpec(name: "Spotify Premium", amount: 21.90, dueInDays: 0, category: .subscriptions),
            BillSpec(name: "Celular — Claro", amount: 59.90, dueInDays: 3, category: .utilities, providerURL: "https://www.claro.com.br"),
            BillSpec(name: "Conta de luz — Enel", amount: 245, dueInDays: 6, category: .utilities, accountIdentifier: "••••2276", providerURL: "https://www.enel.com.br"),
            BillSpec(name: "Água — Sabesp", amount: 98, dueInDays: 9, category: .utilities, providerURL: "https://www.sabesp.com.br"),
            BillSpec(name: "Seguro do carro — Porto Seguro", amount: 185, dueInDays: 11, category: .insurance, providerURL: "https://www.portoseguro.com.br"),
            BillSpec(name: "Academia — Smart Fit", amount: 129.90, dueInDays: 13, category: .subscriptions),
            BillSpec(name: "Empréstimo pessoal", amount: 350, dueInDays: 16, category: .loans, accountIdentifier: "••••5540"),
            BillSpec(name: "Plano de saúde", amount: 480, dueInDays: 18, category: .insurance),
            BillSpec(name: "Aluguel", amount: 1800, dueInDays: 23, category: .housing, accountIdentifier: "••••4821"),
            BillSpec(name: "Netflix", amount: 44.90, dueInDays: 25, category: .subscriptions, providerURL: "https://www.netflix.com"),
            BillSpec(name: "Internet — Vivo Fibra", amount: 119.90, dueInDays: 27, category: .utilities, accountIdentifier: "••••7302", providerURL: "https://www.vivo.com.br"),
            BillSpec(name: "Financiamento do carro", amount: 890, dueInDays: 30, category: .loans, accountIdentifier: "••••9917")
        ],
        yearlyBill: BillSpec(name: "Amazon Prime", amount: 166.80, dueInDays: 11, category: .subscriptions, providerURL: "https://www.amazon.com.br"),
        primaryIncome: IncomeSpec(name: "Salário", amount: 4200, cadence: .monthly(inDays: 27)),
        sideIncome: IncomeSpec(name: "Freelance", amount: 1200, cadence: .monthly(inDays: 11))
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

        // Monthly bills anchored 3 months before their next due date so
        // history is fully populated.
        for (index, spec) in dataset.monthlyBills.enumerated() {
            let nextDueDate = date(inDays: spec.dueInDays, from: todayStart, calendar: calendar)
            let rule = RecurrenceRule(
                pattern: .monthly,
                frequency: 1,
                dayOfWeek: nil,
                dayOfMonth: calendar.component(.day, from: nextDueDate),
                endConditionType: .never,
                endDate: nil
            )
            let bill = Bill(
                name: spec.name,
                amount: spec.amount,
                currencyCode: dataset.currencyCode,
                dueDate: calendar.date(byAdding: .month, value: -3, to: nextDueDate) ?? nextDueDate,
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
        let yearlyNextDue = date(inDays: dataset.yearlyBill.dueInDays, from: todayStart, calendar: calendar)
        let yearly = Bill(
            name: dataset.yearlyBill.name,
            amount: dataset.yearlyBill.amount,
            currencyCode: dataset.currencyCode,
            dueDate: calendar.date(byAdding: .year, value: -1, to: yearlyNextDue) ?? yearlyNextDue,
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
            context.insert(income(from: spec, currencyCode: dataset.currencyCode, todayStart: todayStart, calendar: calendar))
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
        todayStart: Date,
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
                to: previousFriday(onOrBefore: todayStart, calendar: calendar)
            ) ?? todayStart
        case .monthly(let inDays):
            let nextDate = date(inDays: inDays, from: todayStart, calendar: calendar)
            rule = RecurrenceRule(
                pattern: .monthly,
                frequency: 1,
                dayOfWeek: nil,
                dayOfMonth: calendar.component(.day, from: nextDate),
                endConditionType: .never,
                endDate: nil
            )
            startDate = calendar.date(byAdding: .month, value: -3, to: nextDate) ?? nextDate
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

    /// The day `inDays` days after `todayStart`.
    private static func date(inDays: Int, from todayStart: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: inDays, to: todayStart) ?? todayStart
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
