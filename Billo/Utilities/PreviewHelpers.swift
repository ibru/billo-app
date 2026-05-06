//  Created by Jiri Urbasek on 11/26/25.

import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Preview Stubs

@MainActor
private final class PreviewUNNotificationCenter: UNNotificationCenterProtocol {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { false }
    func authorizationStatus() async -> UNAuthorizationStatus { .notDetermined }
    func pendingNotificationRequests() async -> [UNNotificationRequest] { [] }
    func add(_ request: UNNotificationRequest) async throws {}
    func removePendingNotificationRequests(withIdentifiers: [String]) {}
    func removeAllPendingNotificationRequests() {}
    func setBadgeCount(_ count: Int) async throws {}
}

@MainActor
struct BilloPreviewContainer {
    let container: ModelContainer
    let context: ModelContext
    let billsModel: BillsModel
    let notificationCoordinator: NotificationCoordinator
    let preferencesStore: NotificationPreferencesStore
    let appSettingsModel: AppSettingsModel
    let bills: [Bill]

    static func withSampleData(referenceDate: Date = Date()) -> BilloPreviewContainer {
        let schema = Schema([
            Bill.self,
            PaymentEntry.self,
            IssuedOccurrence.self,
            RecurrenceRule.self,
            Income.self,
            CustomCategory.self,
            AppSettings.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        // Create bills
        let calendar = Calendar.current
        let now = referenceDate
        let defaultCurrency = AppSettingsModel.defaultCurrency ?? "USD"
        let sampleBills: [Bill] = [
            Bill(
                name: "Water bill",
                amount: 800,
                dueDate: calendar.date(byAdding: .day, value: 2, to: now) ?? now,
                categoryIdentifier: .predefined(.utilities)
            ),
            Bill(
                name: "Mortgage",
                amount: 5800,
                dueDate: calendar.date(byAdding: .day, value: 10, to: now) ?? now,
                categoryIdentifier: .predefined(.housing),
                recurrenceRule: .init(pattern: .monthly, frequency: 1, dayOfWeek: nil, dayOfMonth: 1, endConditionType: .never, endDate: nil)
            ),
            Bill(
                name: "Streaming subscription",
                amount: 350,
                dueDate: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                categoryIdentifier: .predefined(.subscriptions),
                recurrenceRule: .init(pattern: .weekly, frequency: 1, dayOfWeek: .monday, dayOfMonth: nil, endConditionType: .never, endDate: nil)
            ),
            Bill(
                name: "Electricity",
                amount: 420.30,
                dueDate: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                categoryIdentifier: .predefined(.utilities)
            ),
            Bill(
                name: "Kidds school loan repayment",
                amount: 1359.50,
                dueDate: calendar.date(byAdding: .day, value: 22, to: now) ?? now,
                categoryIdentifier: .predefined(.subscriptions),
                recurrenceRule: .init(pattern: .monthly, frequency: 1, dayOfWeek: nil, dayOfMonth: 15, endConditionType: .never, endDate: nil)
            )
        ]

        sampleBills.forEach { context.insert($0) }

        // Create incomes
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let salaryRule = RecurrenceRule(pattern: .monthly, frequency: 1, dayOfWeek: nil, dayOfMonth: 1, endConditionType: .never, endDate: nil)
        let salary = Income(
            name: "Salary",
            amount: 4200,
            currencyCode: defaultCurrency,
            startDate: startOfMonth,
            recurrenceRule: salaryRule
        )
        let freelance = Income(
            name: "Freelance",
            amount: 650,
            currencyCode: defaultCurrency,
            startDate: calendar.date(byAdding: .day, value: 6, to: now) ?? now
        )
        context.insert(salary)
        context.insert(freelance)

        // Mark one bill as paid
        if let paidBill = sampleBills.last {
            let key = paidBill.occurrenceKey(for: paidBill.dueDate, calendar: calendar)
            let issued = IssuedOccurrence(
                occurrenceKey: key,
                dueDate: paidBill.dueDate,
                billName: paidBill.name,
                billAmount: paidBill.amount,
                billCurrencyCode: paidBill.currencyCode,
                billAccountIdentifier: paidBill.accountIdentifier,
                billNotes: paidBill.notes,
                billCategoryRawValue: paidBill.categoryIdentifier?.rawValue,
                bill: paidBill
            )
            context.insert(issued)

            let payment = PaymentEntry(
                amount: paidBill.amount,
                datePaid: now,
                confirmationNumber: "PREVIEW-1234",
                issuedOccurrence: issued
            )
            context.insert(payment)
        }

        try? context.save()

        let preferencesStore = NotificationPreferencesStore(userDefaults: UserDefaults(suiteName: "preview")!)
        let notificationCoordinator = NotificationCoordinator(
            notificationCenter: PreviewUNNotificationCenter(),
            preferences: preferencesStore
        )
        let billsModel = BillsModel(
            modelContext: context,
            calendar: calendar,
            currentDate: { referenceDate },
            notificationCoordinator: notificationCoordinator,
            notificationPreferences: preferencesStore
        )
        try? billsModel.refresh()

        // Set up app settings with default currency
        let previewSettings = AppSettings(currencyCode: defaultCurrency)
        context.insert(previewSettings)
        try? context.save()

        let appSettingsModel = AppSettingsModel(
            modelContext: context,
            billsModel: billsModel,
            notificationCoordinator: notificationCoordinator
        )
        appSettingsModel.load()

        return BilloPreviewContainer(
            container: container,
            context: context,
            billsModel: billsModel,
            notificationCoordinator: notificationCoordinator,
            preferencesStore: preferencesStore,
            appSettingsModel: appSettingsModel,
            bills: sampleBills
        )
    }

    /// Sample data spanning ~3 past months → current → 2 future months so the
    /// calendar can demonstrate every monthly-header variation:
    ///
    /// - 3 months ago — all bills fully paid → income / paid-green
    /// - 2 months ago — mix of paid + missed → income / paid-green / red unpaid
    /// - 1 month ago — only missed bills → income / red unpaid
    /// - current month — partial pre-payment + upcoming bills (current 2-color)
    /// - +1 month — purely future bills (current 2-color)
    static func withHistoricalSampleData(referenceDate: Date = Date()) -> BilloPreviewContainer {
        let schema = Schema([
            Bill.self,
            PaymentEntry.self,
            IssuedOccurrence.self,
            RecurrenceRule.self,
            Income.self,
            CustomCategory.self,
            AppSettings.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let calendar = Calendar.current
        let defaultCurrency = AppSettingsModel.defaultCurrency ?? "USD"

        // Anchor the historical scenarios on the first of each relevant month so
        // their behavior doesn't drift if `referenceDate` lands on the 1st of a month.
        func startOfMonth(offset months: Int) -> Date {
            let base = calendar.date(byAdding: .month, value: months, to: referenceDate) ?? referenceDate
            let comps = calendar.dateComponents([.year, .month], from: base)
            return calendar.date(from: comps) ?? base
        }
        func dayInMonth(monthOffset: Int, day: Int) -> Date {
            let monthStart = startOfMonth(offset: monthOffset)
            return calendar.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart
        }

        // MARK: Bills

        // 3 months ago — fully paid (header: + income / - paid-green)
        let rentMinus3 = Bill(
            name: "Rent",
            amount: 1500,
            dueDate: dayInMonth(monthOffset: -3, day: 1),
            categoryIdentifier: .predefined(.housing)
        )
        let utilitiesMinus3 = Bill(
            name: "Utilities",
            amount: 220,
            dueDate: dayInMonth(monthOffset: -3, day: 12),
            categoryIdentifier: .predefined(.utilities)
        )

        // 2 months ago — mix of paid + missed (header: + income / - paid-green / - red unpaid)
        let rentMinus2 = Bill(
            name: "Rent",
            amount: 1500,
            dueDate: dayInMonth(monthOffset: -2, day: 1),
            categoryIdentifier: .predefined(.housing)
        )
        let internetMinus2 = Bill(
            name: "Internet",
            amount: 80,
            dueDate: dayInMonth(monthOffset: -2, day: 8),
            categoryIdentifier: .predefined(.utilities)
        )
        let phoneMinus2 = Bill(
            name: "Phone (missed)",
            amount: 65,
            dueDate: dayInMonth(monthOffset: -2, day: 20),
            categoryIdentifier: .predefined(.subscriptions)
        )

        // 1 month ago — only missed bills (header: + income / - red unpaid only)
        let rentMinus1 = Bill(
            name: "Rent (missed)",
            amount: 1500,
            dueDate: dayInMonth(monthOffset: -1, day: 1),
            categoryIdentifier: .predefined(.housing)
        )
        let gymMinus1 = Bill(
            name: "Gym (missed)",
            amount: 45,
            dueDate: dayInMonth(monthOffset: -1, day: 15),
            categoryIdentifier: .predefined(.subscriptions)
        )

        // Current month — pre-payment + upcoming (current 2-color: + income / - red outstanding)
        let rentCurrent = Bill(
            name: "Rent",
            amount: 1500,
            dueDate: dayInMonth(monthOffset: 0, day: 1),
            categoryIdentifier: .predefined(.housing)
        )
        let streamingCurrent = Bill(
            name: "Streaming",
            amount: 18,
            dueDate: dayInMonth(monthOffset: 0, day: 22),
            categoryIdentifier: .predefined(.subscriptions)
        )

        // +1 month — purely future
        let rentFuture = Bill(
            name: "Rent",
            amount: 1500,
            dueDate: dayInMonth(monthOffset: 1, day: 1),
            categoryIdentifier: .predefined(.housing)
        )
        let insuranceFuture = Bill(
            name: "Insurance",
            amount: 320,
            dueDate: dayInMonth(monthOffset: 1, day: 10),
            categoryIdentifier: .predefined(.utilities)
        )

        let allBills: [Bill] = [
            rentMinus3, utilitiesMinus3,
            rentMinus2, internetMinus2, phoneMinus2,
            rentMinus1, gymMinus1,
            rentCurrent, streamingCurrent,
            rentFuture, insuranceFuture
        ]
        allBills.forEach { context.insert($0) }

        // MARK: Payments — only the historical ones we want to surface as "paid"
        // -3 months: both fully paid
        insertPayment(for: rentMinus3, on: dayInMonth(monthOffset: -3, day: 1), amount: rentMinus3.amount, in: context, calendar: calendar)
        insertPayment(for: utilitiesMinus3, on: dayInMonth(monthOffset: -3, day: 14), amount: utilitiesMinus3.amount, in: context, calendar: calendar)

        // -2 months: rent + internet paid; phone missed
        insertPayment(for: rentMinus2, on: dayInMonth(monthOffset: -2, day: 2), amount: rentMinus2.amount, in: context, calendar: calendar)
        insertPayment(for: internetMinus2, on: dayInMonth(monthOffset: -2, day: 9), amount: internetMinus2.amount, in: context, calendar: calendar)

        // Current month: pre-pay streaming partially to also exercise partial in current month
        insertPayment(for: streamingCurrent, on: dayInMonth(monthOffset: 0, day: 5), amount: 10, in: context, calendar: calendar)

        // MARK: Incomes — monthly recurring salary covering the whole range
        let salaryStart = dayInMonth(monthOffset: -3, day: 1)
        let salaryRule = RecurrenceRule(
            pattern: .monthly,
            frequency: 1,
            dayOfWeek: nil,
            dayOfMonth: 1,
            endConditionType: .never,
            endDate: nil
        )
        let salary = Income(
            name: "Salary",
            amount: 4200,
            currencyCode: defaultCurrency,
            startDate: salaryStart,
            recurrenceRule: salaryRule
        )
        context.insert(salary)

        // One-off freelance income two months ago to show varying income totals
        let freelance = Income(
            name: "Freelance",
            amount: 750,
            currencyCode: defaultCurrency,
            startDate: dayInMonth(monthOffset: -2, day: 18)
        )
        context.insert(freelance)

        try? context.save()

        let preferencesStore = NotificationPreferencesStore(userDefaults: UserDefaults(suiteName: "preview-historical")!)
        let notificationCoordinator = NotificationCoordinator(
            notificationCenter: PreviewUNNotificationCenter(),
            preferences: preferencesStore
        )
        let billsModel = BillsModel(
            modelContext: context,
            calendar: calendar,
            currentDate: { referenceDate },
            notificationCoordinator: notificationCoordinator,
            notificationPreferences: preferencesStore
        )
        try? billsModel.refresh()

        let previewSettings = AppSettings(currencyCode: defaultCurrency)
        context.insert(previewSettings)
        try? context.save()

        let appSettingsModel = AppSettingsModel(
            modelContext: context,
            billsModel: billsModel,
            notificationCoordinator: notificationCoordinator
        )
        appSettingsModel.load()

        return BilloPreviewContainer(
            container: container,
            context: context,
            billsModel: billsModel,
            notificationCoordinator: notificationCoordinator,
            preferencesStore: preferencesStore,
            appSettingsModel: appSettingsModel,
            bills: allBills
        )
    }

    static func empty(referenceDate: Date = Date()) -> BilloPreviewContainer {
        let schema = Schema([
            Bill.self,
            PaymentEntry.self,
            IssuedOccurrence.self,
            RecurrenceRule.self,
            Income.self,
            CustomCategory.self,
            AppSettings.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let preferencesStore = NotificationPreferencesStore(userDefaults: UserDefaults(suiteName: "preview")!)
        let notificationCoordinator = NotificationCoordinator(
            notificationCenter: PreviewUNNotificationCenter(),
            preferences: preferencesStore
        )
        let billsModel = BillsModel(
            modelContext: context,
            calendar: Calendar.current,
            currentDate: { referenceDate },
            notificationCoordinator: notificationCoordinator,
            notificationPreferences: preferencesStore
        )
        try? billsModel.refresh()

        // Set up app settings with default currency
        let defaultCurrency = AppSettingsModel.defaultCurrency ?? "USD"
        let previewSettings = AppSettings(currencyCode: defaultCurrency)
        context.insert(previewSettings)
        try? context.save()

        let appSettingsModel = AppSettingsModel(
            modelContext: context,
            billsModel: billsModel,
            notificationCoordinator: notificationCoordinator
        )
        appSettingsModel.load()

        return BilloPreviewContainer(
            container: container,
            context: context,
            billsModel: billsModel,
            notificationCoordinator: notificationCoordinator,
            preferencesStore: preferencesStore,
            appSettingsModel: appSettingsModel,
            bills: []
        )
    }

    func billModel(for bill: Bill) -> BillModel {
        BillModel(bill: bill, modelContext: context)
    }
}

// MARK: - Preview helpers

@MainActor
private func insertPayment(
    for bill: Bill,
    on datePaid: Date,
    amount: Decimal,
    in context: ModelContext,
    calendar: Calendar
) {
    let issued = IssuedOccurrence(
        occurrenceKey: bill.occurrenceKey(for: bill.dueDate, calendar: calendar),
        dueDate: bill.dueDate,
        billName: bill.name,
        billAmount: bill.amount,
        billCurrencyCode: bill.currencyCode,
        billAccountIdentifier: bill.accountIdentifier,
        billNotes: bill.notes,
        billCategoryRawValue: bill.categoryIdentifier?.rawValue,
        bill: bill
    )
    context.insert(issued)

    let payment = PaymentEntry(
        amount: amount,
        datePaid: datePaid,
        confirmationNumber: nil,
        issuedOccurrence: issued
    )
    context.insert(payment)
}

extension View {
    func billoPreviewEnvironment(_ preview: BilloPreviewContainer, colorScheme: ColorScheme? = nil) -> some View {
        self
            .environment(preview.billsModel)
            .environment(preview.notificationCoordinator)
            .environment(preview.preferencesStore)
            .environment(preview.appSettingsModel)
            .modelContainer(preview.container)
            .preferredColorScheme(colorScheme)
    }
}
