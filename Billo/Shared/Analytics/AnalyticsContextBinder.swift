//  Created by Jiri Urbasek on 07/10/26.

import SwiftUI

extension View {
    func bindAnalyticsContext(
        analytics: AnalyticsModel,
        billsModel: BillsModel,
        storeKitManager: StoreKitManager,
        preferences: NotificationPreferencesStore
    ) -> some View {
        modifier(AnalyticsContextBinder(
            analytics: analytics,
            billsModel: billsModel,
            storeKitManager: storeKitManager,
            preferences: preferences
        ))
    }
}

private struct AnalyticsContextBinder: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    let analytics: AnalyticsModel
    let billsModel: BillsModel
    let storeKitManager: StoreKitManager
    let preferences: NotificationPreferencesStore

    func body(content: Content) -> some View {
        content
            .task {
                updateContext()
            }
            .onChange(of: storeKitManager.isPro) { _, _ in
                updateContext()
            }
            .onChange(of: billsModel.bills.count) { _, _ in
                updateContext()
            }
            .onChange(of: billsModel.incomes.count) { _, _ in
                updateContext()
            }
            .onChange(of: preferences.remindersEnabled) { _, _ in
                updateContext()
            }
            .onChange(of: preferences.digestEnabled) { _, _ in
                updateContext()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                updateContext()
            }
    }

    private func updateContext() {
        analytics.register(superProperties: [
            "is_pro": storeKitManager.isPro,
            "bill_count": billsModel.bills.count,
            "income_count": billsModel.incomes.count,
            "reminders_enabled": preferences.remindersEnabled,
            "digest_enabled": preferences.digestEnabled,
            "platform": platformValue,
            "device_type": deviceTypeValue,
            "app_version": appVersion,
            "build_number": buildNumber,
            "locale": Locale.current.identifier
        ])
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    }

    private var platformValue: String {
        #if targetEnvironment(macCatalyst)
        return "macos"
        #elseif os(iOS)
        return "ios"
        #elseif os(macOS)
        return "macos"
        #else
        return "unknown"
        #endif
    }

    private var deviceTypeValue: String {
        #if targetEnvironment(macCatalyst)
        return "mac"
        #elseif os(iOS)
        if ProcessInfo.processInfo.isiOSAppOnMac { return "mac" }
        return UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        #elseif os(macOS)
        return "mac"
        #else
        return "unknown"
        #endif
    }
}
