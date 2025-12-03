//  Created by Jiri Urbasek on 11/26/25.

import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Preview Stubs

@MainActor
private final class PreviewNotificationCoordinator: NotificationCoordinating {
    func currentAuthorizationStatus() async -> UNAuthorizationStatus { .notDetermined }
    func requestAuthorization() async throws -> Bool { false }
    func cancelReminders(for occurrenceIDs: [BillOccurrence.OccurrenceID]) async {}
    func cancelAllReminders(forBillID billID: String) async {}
    func scheduleReminders(for occurrences: [BillOccurrence]) async throws {}
    func rescheduleReminders(forBillID billID: String, newOccurrences: [BillOccurrence]) async throws {}
    func updateBadge(unpaidCount: Int) async {}
    func clearBadge() async {}
    func refreshAllNotifications(for bills: [Bill]) async throws {}
    func scheduleDigest(billsDueCount: Int, totalAmount: Decimal?, currencyCode: String?) async throws {}
    func cancelDigest() async {}
}

@MainActor
private final class PreviewNotificationPreferences: NotificationPreferencesReading {
    var remindersEnabled: Bool { true }
    var reminderOffsets: [Int] { [0, 3] }
    var reminderTime: DateComponents { DateComponents(hour: 9, minute: 0) }
    var digestEnabled: Bool { false }
    var digestLookaheadDays: Int { 5 }
    var digestTime: DateComponents { DateComponents(hour: 9, minute: 0) }
    var badgeMode: BadgeMode { .daysBefore(3) }
}

@MainActor
struct BilloPreviewContainer {
    let container: ModelContainer
    let context: ModelContext
    let billsModel: BillsModel
    let paymentHistoryModel: PaymentHistoryModel
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
                categoryIdentifier: .predefined(.housing)
            ),
            Bill(
                name: "Streaming subscription",
                amount: 350,
                dueDate: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                categoryIdentifier: .predefined(.subscriptions)
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

        let paymentHistoryModel = PaymentHistoryModel(modelContext: context)
        let billsModel = BillsModel(
            modelContext: context,
            calendar: calendar,
            currentDate: { referenceDate },
            paymentHistoryRefresher: paymentHistoryModel,
            notificationCoordinator: PreviewNotificationCoordinator(),
            notificationPreferences: PreviewNotificationPreferences()
        )
        try? billsModel.refresh()

        return BilloPreviewContainer(
            container: container,
            context: context,
            billsModel: billsModel,
            paymentHistoryModel: paymentHistoryModel,
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

        let paymentHistoryModel = PaymentHistoryModel(modelContext: context)
        let billsModel = BillsModel(
            modelContext: context,
            calendar: Calendar.current,
            currentDate: { referenceDate },
            paymentHistoryRefresher: paymentHistoryModel,
            notificationCoordinator: PreviewNotificationCoordinator(),
            notificationPreferences: PreviewNotificationPreferences()
        )
        try? billsModel.refresh()

        return BilloPreviewContainer(
            container: container,
            context: context,
            billsModel: billsModel,
            paymentHistoryModel: paymentHistoryModel,
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
            .modelContainer(preview.container)
            .preferredColorScheme(colorScheme)
    }
}
