//  Created by Jiri Urbasek on 12/02/25.

import SwiftUI
import UserNotifications
#if os(iOS)
import UIKit
#endif

struct NotificationSettingsView: View {
    @Environment(NotificationSettingsModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Form {
            Section {
                permissionStatusView
            }

            Section("Bill Reminders") {
                Toggle("Enable Reminders", isOn: Binding(
                    get: { model.effectiveReminderToggleState },
                    set: { model.toggleReminders(to: $0) }
                ))
                .help("Reminders require notification permission")

                if model.effectiveReminderToggleState {
                    reminderScheduleSection
                    reminderTimePicker
                }
            }

            Section("Daily Summary") {
                Toggle("Daily Digest", isOn: Binding(
                    get: { model.digestEnabled },
                    set: { model.setDigestEnabled($0) }
                ))
                .help("Get a daily summary of upcoming bills")

                if model.digestEnabled {
                    Picker("Look Ahead", selection: Binding(
                        get: { model.digestLookaheadDays },
                        set: { model.setDigestLookaheadDays($0) }
                    )) {
                        Text("3 days").tag(3)
                        Text("5 days").tag(5)
                        Text("7 days").tag(7)
                    }

                    digestTimePicker
                }
            }

            Section("App Badge") {
                badgeModePicker
            }
        }
        .navigationTitle("Notification Settings")
        .alert(
            "Notifications Disabled",
            isPresented: Binding(
                get: { model.showPermissionDeniedAlert },
                set: { model.showPermissionDeniedAlert = $0 }
            )
        ) {
            Button("Cancel", role: .cancel) { }
#if os(iOS)
            Button("Open Settings") {
                model.openSettings()
            }
#endif
        } message: {
            Text("Enable notifications in Settings to receive bill reminders.")
        }
        .task {
            await model.loadAuthorizationStatus()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await model.onScenePhaseChange(scenePhase)
        }
    }

    // MARK: - Permission Status

    @ViewBuilder
    private var permissionStatusView: some View {
        switch model.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            Label("Notifications Enabled", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Label("Notifications Disabled", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("Enable in Settings to receive reminders")
                    .font(.caption)
                    .foregroundStyle(.secondary)
#if os(iOS)
                Button("Open Settings") {
                    model.openSettings()
                }
                .buttonStyle(.bordered)
#endif
                Text("Reminders stay off until permission is granted.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .notDetermined:
            Label("Notifications Not Yet Configured", systemImage: "bell.badge")
                .foregroundStyle(.secondary)
        @unknown default:
            EmptyView()
        }
    }

    // MARK: - Reminder Schedule

    @ViewBuilder
    private var reminderScheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reminder Schedule")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Select when to receive reminders:")
                .font(.caption)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                ForEach(NotificationPreferencesStore.availableOffsets, id: \.self) { offset in
                    offsetButton(offset)
                }
            }

            Text("At least one must be selected • Applies to all bills")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private func offsetButton(_ offset: Int) -> some View {
        let isSelected = model.reminderOffsets.contains(offset)
        let label = offset == 0 ? "Day of" : "\(offset) days"

        return Button {
            model.toggleReminderOffset(offset)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                Text(label)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) before due date")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Time Pickers

    private var reminderTimePicker: some View {
        DatePicker(
            "Reminder Time",
            selection: Binding(
                get: {
                    let components = model.reminderTime
                    return Calendar.current.date(from: components) ?? Date()
                },
                set: { newValue in
                    let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                    model.setReminderTime(components)
                }
            ),
            displayedComponents: .hourAndMinute
        )
    }

    private var digestTimePicker: some View {
        DatePicker(
            "Digest Time",
            selection: Binding(
                get: {
                    let components = model.digestTime
                    return Calendar.current.date(from: components) ?? Date()
                },
                set: { newValue in
                    let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                    model.setDigestTime(components)
                }
            ),
            displayedComponents: .hourAndMinute
        )
    }

    // MARK: - Badge Mode

    private var badgeModePicker: some View {
        Picker("Badge Window", selection: Binding(
            get: { model.badgeMode },
            set: { model.setBadgeMode($0) }
        )) {
            Text("Never").tag(BadgeMode.never)
            Text("Due / Overdue only").tag(BadgeMode.dueAndOverdue)
            Text("1 day before").tag(BadgeMode.daysBefore(1))
            Text("3 days before").tag(BadgeMode.daysBefore(3))
            Text("5 days before").tag(BadgeMode.daysBefore(5))
            Text("7 days before").tag(BadgeMode.daysBefore(7))
        }
        .help("Badge counts unpaid occurrences within selected window")
    }
}

#Preview {
    let preferences = PreviewNotificationPreferencesStore()
    let coordinator = PreviewNotificationCoordinator()

    return NavigationStack {
        NotificationSettingsView()
            .environment(
                NotificationSettingsModel(
                    preferences: preferences,
                    coordinator: coordinator,
                    openSettingsHandler: { }
                )
            )
    }
}

// MARK: - Preview Helpers

private final class PreviewNotificationPreferencesStore: NotificationPreferencesProviding, @unchecked Sendable {
    var remindersEnabled: Bool = true
    var reminderOffsets: [Int] = NotificationPreferencesStore.defaultReminderOffsets
    var reminderTime: DateComponents = NotificationPreferencesStore.defaultReminderTime
    var digestEnabled: Bool = true
    var digestLookaheadDays: Int = NotificationPreferencesStore.defaultDigestLookaheadDays
    var digestTime: DateComponents = NotificationPreferencesStore.defaultDigestTime
    var badgeMode: BadgeMode = .dueAndOverdue

    func setRemindersEnabled(_ enabled: Bool) { remindersEnabled = enabled }
    func setReminderOffsets(_ offsets: [Int]) { reminderOffsets = offsets }
    func setReminderTime(_ time: DateComponents) { reminderTime = time }
    func setDigestEnabled(_ enabled: Bool) { digestEnabled = enabled }
    func setDigestLookaheadDays(_ days: Int) { digestLookaheadDays = days }
    func setDigestTime(_ time: DateComponents) { digestTime = time }
    func setBadgeMode(_ mode: BadgeMode) { badgeMode = mode }
}

private final class PreviewNotificationCoordinator: NotificationCoordinating, @unchecked Sendable {
    func currentAuthorizationStatus() async -> UNAuthorizationStatus { .authorized }
    func requestAuthorization() async throws -> Bool { true }
    func refreshAllNotifications(for bills: [Bill]) async throws { }
    func scheduleReminders(for occurrences: [BillOccurrence]) async throws { }
    func cancelReminders(for occurrenceIDs: [BillOccurrence.OccurrenceID]) async { }
    func cancelAllReminders(forBillID billID: String) async { }
    func rescheduleReminders(forBillID billID: String, newOccurrences: [BillOccurrence]) async throws { }
    func scheduleDigest(billsDueCount: Int, totalAmount: Decimal?, currencyCode: String?) async throws { }
    func cancelDigest() async { }
    func updateBadge(unpaidCount: Int) async { }
    func clearBadge() async { }
}
