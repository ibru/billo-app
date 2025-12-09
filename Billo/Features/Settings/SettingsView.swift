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
        return "\(name) (\(code))"
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
        }
        .navigationTitle("Settings")
    }
}
