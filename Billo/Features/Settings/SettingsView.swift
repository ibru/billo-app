//  Created by Jiri Urbasek on 12/08/25.

import SwiftUI

struct SettingsView: View {
    @Environment(AppSettingsModel.self) private var appSettingsModel
    private let notificationSettingsModel: NotificationSettingsModel

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

            Section {
                aboutFooter
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Settings")
        .analyticsScreen(.settings)
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
