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
    let paymentHistoryModel: PaymentHistoryModel
    let notificationCoordinator: NotificationCoordinator
    let preferencesStore: NotificationPreferencesStore
    let bills: [Bill]

    static func withSampleData(referenceDate: Date = Date()) -> BilloPreviewContainer {
        let schema = Schema([
            Bill.self,
            Payment.self,
            RecurrenceRule.self,
            Income.self,
            CustomCategory.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        // Create bills
        let calendar = Calendar.current
        let now = referenceDate
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

        // Mark one bill as paid
        if let paidBill = sampleBills.last {
            let payment = Payment(
                amount: paidBill.amount,
                datePaid: now,
                occurrenceDate: paidBill.dueDate,
                confirmationNumber: "PREVIEW-1234",
                bill: paidBill
            )
            paidBill.payments.append(payment)
            context.insert(payment)
        }

        sampleBills.forEach { context.insert($0) }

        try? context.save()

        let preferencesStore = NotificationPreferencesStore(userDefaults: UserDefaults(suiteName: "preview")!)
        let notificationCoordinator = NotificationCoordinator(
            notificationCenter: PreviewUNNotificationCenter(),
            preferences: preferencesStore
        )
        let paymentHistoryModel = PaymentHistoryModel(modelContext: context)
        let billsModel = BillsModel(
            modelContext: context,
            calendar: calendar,
            currentDate: { referenceDate },
            paymentHistoryRefresher: paymentHistoryModel,
            notificationCoordinator: notificationCoordinator,
            notificationPreferences: preferencesStore
        )
        try? billsModel.refresh()

        return BilloPreviewContainer(
            container: container,
            context: context,
            billsModel: billsModel,
            paymentHistoryModel: paymentHistoryModel,
            notificationCoordinator: notificationCoordinator,
            preferencesStore: preferencesStore,
            bills: sampleBills
        )
    }

    static func empty(referenceDate: Date = Date()) -> BilloPreviewContainer {
        let schema = Schema([
            Bill.self,
            Payment.self,
            RecurrenceRule.self,
            Income.self,
            CustomCategory.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let preferencesStore = NotificationPreferencesStore(userDefaults: UserDefaults(suiteName: "preview")!)
        let notificationCoordinator = NotificationCoordinator(
            notificationCenter: PreviewUNNotificationCenter(),
            preferences: preferencesStore
        )
        let paymentHistoryModel = PaymentHistoryModel(modelContext: context)
        let billsModel = BillsModel(
            modelContext: context,
            calendar: Calendar.current,
            currentDate: { referenceDate },
            paymentHistoryRefresher: paymentHistoryModel,
            notificationCoordinator: notificationCoordinator,
            notificationPreferences: preferencesStore
        )
        try? billsModel.refresh()

        return BilloPreviewContainer(
            container: container,
            context: context,
            billsModel: billsModel,
            paymentHistoryModel: paymentHistoryModel,
            notificationCoordinator: notificationCoordinator,
            preferencesStore: preferencesStore,
            bills: []
        )
    }

    func billModel(for bill: Bill) -> BillModel {
        BillModel(bill: bill, modelContext: context)
    }
}

extension View {
    func billoPreviewEnvironment(_ preview: BilloPreviewContainer, colorScheme: ColorScheme? = nil) -> some View {
        self
            .environment(preview.billsModel)
            .environment(preview.paymentHistoryModel)
            .environment(preview.notificationCoordinator)
            .environment(preview.preferencesStore)
            .modelContainer(preview.container)
            .preferredColorScheme(colorScheme)
    }
}
