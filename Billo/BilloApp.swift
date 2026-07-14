//
//  BilloApp.swift
//  Billo
//
//  Created by Jiri Urbasek on 11/25/25.
//

import SwiftUI
import SwiftData
import UserNotifications
import PostHog

@main
struct BilloApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Bill.self,
            PaymentEntry.self,
            IssuedOccurrence.self,
            RecurrenceRule.self,
            Income.self,
            IncomeOccurrence.self,
            CustomCategory.self,
            AppSettings.self
        ])
#if SCREENSHOTS || ONBOARDING
        // Screenshots and Onboarding runs use a throwaway in-memory store;
        // CloudKit stays out of the way. Screenshots additionally seeds
        // realistic demo data below; Onboarding starts empty so the
        // first-launch flow always has a clean slate.
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
#else
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
#endif

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
#if SCREENSHOTS
            ScreenshotMockData.seed(into: container.mainContext)
#endif
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var billsModel: BillsModel?
    @State private var notificationCoordinator: NotificationCoordinator?
    @State private var preferencesStore: NotificationPreferencesStore?
    @State private var appSettingsModel: AppSettingsModel?
    @State private var appFlowModel: AppFlowModel?
    @State private var storeKitManager: StoreKitManager?
    @State private var analyticsModel: AnalyticsModel?
    @State private var didInitialNotificationRefresh = false
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
            Group {
                if let billsModel, let notificationCoordinator, let preferencesStore, let appSettingsModel, let appFlowModel, let storeKitManager, let analyticsModel {
                    AppRootView()
                        .environment(billsModel)
                        .environment(notificationCoordinator)
                        .environment(preferencesStore)
                        .environment(appSettingsModel)
                        .environment(appFlowModel)
                        .environment(storeKitManager)
                        .environment(analyticsModel)
                        .bindAnalyticsContext(
                            analytics: analyticsModel,
                            billsModel: billsModel,
                            storeKitManager: storeKitManager,
                            preferences: preferencesStore
                        )
                        // Free-tier display cap reacts to entitlement changes:
                        // purchase reveals hidden items, lapse hides them and
                        // cancels their reminders — one bills + notifications
                        // refresh through the existing refresher path.
                        .onChange(of: storeKitManager.isPro) { _, _ in
                            Task { @MainActor in
                                await refreshNotificationsIfReady()
                            }
                        }
                } else {
                    ProgressView()
                        .task {
                            let context = sharedModelContainer.mainContext

                        // Set up analytics first so services can capture events.
                        let analytics: AnalyticsModel = {
                            guard Self.analyticsEnabled else {
                                return AnalyticsModel(client: NoopAnalyticsClient())
                            }

                            let config = PostHogConfig(projectToken: PostHogKeys.projectToken, host: PostHogKeys.host)
                            config.captureScreenViews = false
                            config.sessionReplay = true
                            config.sessionReplayConfig.screenshotMode = true
                            config.sessionReplayConfig.captureNetworkTelemetry = false
                            config.sessionReplayConfig.maskAllImages = false
                            // Show static UI in replays; sensitive financial values
                            // (amounts, names, notes) are masked per-view via
                            // `.replayMaskSensitive()`.
                            config.sessionReplayConfig.maskAllTextInputs = false
                            PostHogSDK.shared.setup(config)

                            return AnalyticsModel(client: PostHogAnalyticsClient())
                        }()

                        // Set up notification system
#if SCREENSHOTS
                        let center: UNNotificationCenterProtocol = ScreenshotNoopNotificationCenter()
#else
                        let center = UNUserNotificationCenter.current()
#endif
                        let preferences = NotificationPreferencesStore()
                        let coordinator = NotificationCoordinator(
                            notificationCenter: center,
                            preferences: preferences,
                            occurrenceProvider: BillOccurrenceProvider(),
                            calendar: .current,
                            currentDate: { Date() }
                        )

                        // StoreKit must exist before BillsModel — the model's
                        // free-tier display cap reads live entitlement.
#if SCREENSHOTS
                        // Pro unlocked without touching StoreKit, so screenshots
                        // never show locked features or entitlement loading states.
                        let storeKit = StoreKitManager(isPro: true)
#elseif ONBOARDING
                        // Non-pro on every LAUNCH: StoreKit is never started and
                        // the entitlement cache is a no-op, so a cached `true`
                        // from a previous run can't hide the Pro gates during QA.
                        // (Purchasing on the paywall mid-session still flips
                        // `isPro` until the next launch — useful for QA too.)
                        let storeKit = StoreKitManager(isPro: false)
#else
                        let storeKit = StoreKitManager()
#endif

                        // Set up notification delegate references
                        notificationDelegate.modelContainer = sharedModelContainer
                        notificationDelegate.notificationCoordinator = coordinator
                        notificationDelegate.notificationPreferences = preferences
                        notificationDelegate.analyticsCapture = { event in analytics.capture(event) }
                        notificationDelegate.isProProvider = { storeKit.isPro }

                        let bills = BillsModel(
                            modelContext: context,
                            notificationCoordinator: coordinator,
                            notificationPreferences: preferences,
                            analyticsCapture: { event in analytics.capture(event) },
                            isPro: { storeKit.isPro }
                        )

                        // Set up app settings
                        let settings = AppSettingsModel(
                            modelContext: context,
                            billsModel: bills,
                            notificationCoordinator: coordinator
                        )
                        settings.load()

#if DEBUG
//                         DEBUG: Reset first-launch onboarding.
//                         Uncomment to force the marketing onboarding + paywall to show again.
                        
//                         do {
//                             var persistence = AppPersistence()
//                             persistence.resetAll()
//                        
//                             let appSettings = AppSettings.getOrCreate(in: context)
//                             appSettings.currencyCode = nil
//                             try context.save()
//                        
//                             settings.load()
//                         } catch {
//                             Logger.log("Failed to reset onboarding: \(error)", level: .error)
//                         }
#endif

#if ONBOARDING
                        // BilloOnboarding scheme: always run the first-launch
                        // flow. The store above is fresh in-memory (so
                        // currencyCode is nil and the launch-time skip never
                        // fires); the local completion flags persist in
                        // UserDefaults, so clear them on every launch.
                        AppPersistence().resetAll()
#endif

                        let flow = AppFlowModel()

                        if settings.currencyCode != nil {
                            flow.completeOnboarding()
                            flow.markFirstLaunchPaywallShown()
                        }

                        do {
                            try bills.refresh()
                        } catch {
                            Logger.log("Failed to refresh bills on launch: \(error)", level: .error)
                        }

                            billsModel = bills
                            notificationCoordinator = coordinator
                            preferencesStore = preferences
                            appSettingsModel = settings
                            appFlowModel = flow
                            storeKitManager = storeKit
                            analyticsModel = analytics

#if !SCREENSHOTS && !ONBOARDING
                            // Start AFTER the state is published so the ready
                            // branch's `onChange(of: isPro)` observer is (about
                            // to be) attached when the async entitlement
                            // verification lands — starting earlier leaves a
                            // window where a flip goes unobserved and the
                            // display cap stays stale until the next refresh.
                            storeKit.start()
#endif
                        }
                }
            }
            .tint(DesignSystem.Color.green)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: billsModel != nil) { _, isReady in
            // Initial notification refresh when app state becomes ready.
            // Bills already refreshed in setup task, so skip redundant refresh.
            guard isReady, !didInitialNotificationRefresh else { return }
            didInitialNotificationRefresh = true
            Task { @MainActor in
                await refreshNotificationsIfReady(refreshBills: false)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                handleAppBecameActive()
            }
        }
    }

    private func handleAppBecameActive() {
        Logger.log("App became active, refreshing notifications", level: .debug)
        guard let billsModel, let notificationCoordinator else { return }

        // Skip initial launch - onChange(of: billsModel) handles it
        guard didInitialNotificationRefresh else { return }

        Task { @MainActor in
            await refreshNotificationsIfReady()
        }
    }

    private func refreshNotificationsIfReady(refreshBills: Bool = true) async {
        guard let billsModel, let notificationCoordinator else { return }
        await appNotificationRefresher.refreshAndReschedule(
            billsModel: billsModel,
            coordinator: notificationCoordinator,
            refreshBills: refreshBills
        )
    }

    /// Analytics is opt-in for developers and always off for tests, previews,
    /// and the screenshots scheme. Release builds send events unconditionally.
    private static var analyticsEnabled: Bool {
        #if SCREENSHOTS
        return false
        #else
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return false }
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return false }

        #if DEBUG
        return ProcessInfo.processInfo.environment["BILLO_ENABLE_ANALYTICS"] == "1"
        #else
        return true
        #endif
        #endif
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
            // Opt into dismiss callbacks so `notification dismissed(daily_digest)`
            // analytics can actually fire; no user-visible behavior change.
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            billReminderCategory,
            digestCategory
        ])
    }
}
