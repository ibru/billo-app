//
//  BilloApp.swift
//  Billo
//
//  Created by Jiri Urbasek on 11/25/25.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct BilloApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Bill.self,
            Payment.self,
            RecurrenceRule.self,
            Income.self,
            CustomCategory.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var billsModel: BillsModel?
    @State private var paymentHistoryModel: PaymentHistoryModel?
    @State private var notificationCoordinator: NotificationCoordinator?
    @State private var preferencesStore: NotificationPreferencesStore?
    private let notificationDelegate = NotificationDelegate()
    private let appNotificationRefresher = AppNotificationRefresher()

    init() {
        // Register notification categories
        registerNotificationCategories()

        // Set notification delegate (strongly held by the app)
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            if let billsModel, let paymentHistoryModel, let notificationCoordinator, let preferencesStore {
                BillsHomeSwitchView()
                    .environment(billsModel)
                    .environment(paymentHistoryModel)
                    .environment(notificationCoordinator)
                    .environment(preferencesStore)
            } else {
                ProgressView()
                    .task {
                        let context = sharedModelContainer.mainContext

                        // Set up notification system
                        let center = UNUserNotificationCenter.current()
                        let preferences = NotificationPreferencesStore()
                        let coordinator = NotificationCoordinator(
                            notificationCenter: center,
                            preferences: preferences,
                            occurrenceProvider: BillOccurrenceProvider(),
                            calendar: .current,
                            currentDate: { Date() }
                        )

                        // Set up notification delegate references
                        notificationDelegate.modelContainer = sharedModelContainer
                        notificationDelegate.notificationCoordinator = coordinator
                        notificationDelegate.notificationPreferences = preferences

                        let historyModel = PaymentHistoryModel(modelContext: context)
                        let bills = BillsModel(
                            modelContext: context,
                            paymentHistoryRefresher: historyModel,
                            notificationCoordinator: coordinator,
                            notificationPreferences: preferences
                        )

                        paymentHistoryModel = historyModel
                        billsModel = bills
                        notificationCoordinator = coordinator
                        preferencesStore = preferences

                        await appNotificationRefresher.refreshAndReschedule(
                            billsModel: bills,
                            coordinator: coordinator
                        )
                    }
            }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                handleAppBecameActive()
            }
        }
    }

    private func handleAppBecameActive() {
        Logger.log("App became active, refreshing notifications", level: .debug)
        guard let billsModel, let notificationCoordinator else { return }

        Task { @MainActor in
            await appNotificationRefresher.refreshAndReschedule(
                billsModel: billsModel,
                coordinator: notificationCoordinator
            )
        }
    }

    private func registerNotificationCategories() {
        let markPaidAction = UNNotificationAction(
            identifier: NotificationAction.markPaid,
            title: String(localized: "Mark Paid"),
            options: [.authenticationRequired]
        )

        let billReminderCategory = UNNotificationCategory(
            identifier: NotificationCategory.billReminder,
            actions: [markPaidAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let digestCategory = UNNotificationCategory(
            identifier: NotificationCategory.dailyDigest,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            billReminderCategory,
            digestCategory
        ])
    }
}
