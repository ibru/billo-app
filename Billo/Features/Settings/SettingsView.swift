//  Created by Jiri Urbasek on 12/08/25.

import SwiftUI

struct SettingsView: View {
    @Environment(AppSettingsModel.self) private var appSettingsModel
    @Environment(StoreKitManager.self) private var storeKit
    @Environment(AnalyticsModel.self) private var analytics
    private let notificationSettingsModel: NotificationSettingsModel

    @State private var paywallContext: PaywallContext?
    @State private var restoreState: RestoreState = .idle

    private enum RestoreState: Equatable {
        case idle
        case restoring
        case finished(message: String)
    }

    init(notificationSettingsModel: NotificationSettingsModel) {
        self.notificationSettingsModel = notificationSettingsModel
    }

    private var currencyDisplayText: String {
        guard let code = appSettingsModel.currencyCode else { return "" }
        let name = Locale.current.localizedString(forCurrencyCode: code) ?? code
        return String(
            localized: "\(name) (\(code))",
            comment: "Settings: currency display label (localized currency name + currency code)"
        )
    }

    var body: some View {
        List {
            Section("General") {
                NavigationLink {
                    SettingsCurrencyPickerView()
                } label: {
                    LabeledContent {
                        Text(currencyDisplayText)
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Currency", systemImage: "dollarsign.circle")
                    }
                }
            }

            Section("Notifications") {
                NavigationLink {
                    NotificationSettingsView()
                        .environment(notificationSettingsModel)
                } label: {
                    Label("Notification Settings", systemImage: "bell.badge")
                }
            }

            Section("Billo Pro") {
                proStatusRow
                restorePurchasesRow
            }

            Section {
                aboutFooter
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Settings")
        .analyticsScreen(.settings)
        .paywallSheet(context: $paywallContext)
        .alert(
            Text("Restore Purchases", comment: "Settings: restore purchases result alert title"),
            isPresented: Binding(
                get: {
                    if case .finished = restoreState { true } else { false }
                },
                set: { isPresented in
                    if isPresented == false { restoreState = .idle }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            if case .finished(let message) = restoreState {
                Text(message)
            }
        }
    }

    // MARK: - Billo Pro

    @ViewBuilder
    private var proStatusRow: some View {
        if storeKit.isPro {
            LabeledContent {
                Text(proPlanDisplayText)
                    .foregroundStyle(.secondary)
            } label: {
                Label {
                    Text("Billo Pro", comment: "Settings: Pro status row title")
                } icon: {
                    Image(systemName: "crown")
                }
            }
        } else {
            Button {
                paywallContext = .settings
            } label: {
                LabeledContent {
                    Text("Free", comment: "Settings: Pro status value when not subscribed")
                        .foregroundStyle(.secondary)
                } label: {
                    Label {
                        Text("Billo Pro", comment: "Settings: Pro status row title")
                            .foregroundStyle(Color.primary)
                    } icon: {
                        Image(systemName: "crown")
                    }
                }
            }
        }
    }

    /// The launch cache persists only the Pro boolean, so a subscriber can be
    /// entitled before the first StoreKit refresh names the plan — fall back
    /// to a generic "Active" until it does.
    private var proPlanDisplayText: String {
        storeKit.activePlan?.displayName
            ?? String(localized: "Active", comment: "Settings: Pro status value when subscribed but plan not yet known")
    }

    private var restorePurchasesRow: some View {
        Button {
            restorePurchases()
        } label: {
            HStack {
                Label {
                    Text("Restore Purchases", comment: "Settings: restore purchases button")
                } icon: {
                    Image(systemName: "arrow.clockwise")
                }

                Spacer()

                if restoreState == .restoring {
                    ProgressView()
                }
            }
        }
        .disabled(restoreState == .restoring)
    }

    private func restorePurchases() {
        Logger.log("Settings restore tapped", level: .info)
        let context = PaywallContext.settings.analyticsKey
        analytics.capture(.paywallRestoreAttempted(context: context))
        restoreState = .restoring

        Task {
            do {
                try await storeKit.restorePurchases()
                // A clean sync with no active entitlement is not a success.
                if storeKit.isPro {
                    analytics.capture(.paywallRestoreSucceeded(context: context))
                    restoreState = .finished(message: String(
                        localized: "Your purchases were restored.",
                        comment: "Settings: restore purchases success message"
                    ))
                } else {
                    analytics.capture(.paywallRestoreFailed(context: context, error: "no_purchases_found"))
                    restoreState = .finished(message: String(
                        localized: "No previous purchases were found.",
                        comment: "Settings: restore purchases message when nothing to restore"
                    ))
                }
            } catch {
                // Stable key only — localizedDescription is locale-dependent
                // (unaggregatable) and an uncontrolled string channel.
                analytics.capture(.paywallRestoreFailed(context: context, error: "sync_failed"))
                restoreState = .finished(message: error.localizedDescription)
            }
        }
    }

    private var aboutFooter: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            AppIconView(size: 56)

            Text("Billo", comment: "Settings footer: app name")
                .font(.footnote.weight(.semibold))

            Text(
                "Version \(appVersion)",
                comment: "Settings footer: app version label"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.small)
        .accessibilityElement(children: .combine)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
