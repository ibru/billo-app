//  Created by Jiri Urbasek on 12/08/25.

import SwiftUI

struct SettingsView: View {
    private let notificationSettingsModel: NotificationSettingsModel

    init(notificationSettingsModel: NotificationSettingsModel) {
        self.notificationSettingsModel = notificationSettingsModel
    }

    var body: some View {
        List {
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
