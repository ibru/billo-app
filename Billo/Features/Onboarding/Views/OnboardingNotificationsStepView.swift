//  Created by Jiri Urbasek on 7/10/26.

import SwiftUI
import UserNotifications

/// Value-framed notification permission ask, placed right after bill setup so
/// the benefit ("we'll remind you before these are due") is concrete. Denial
/// is not a dead end — the user just continues; Notification Settings handles
/// re-enabling later.
struct OnboardingNotificationsStepView: View {
    @Environment(NotificationCoordinator.self) private var notificationCoordinator
    @Environment(NotificationPreferencesStore.self) private var preferencesStore
    @Environment(AnalyticsModel.self) private var analytics

    let billCount: Int
    /// `didSkip` distinguishes "Not now" from the primary path so the funnel
    /// can attribute it as a skip — a denied permission after tapping
    /// "Turn On Reminders" is still a continue, not a skip.
    let onFinished: (_ remindersEnabled: Bool, _ didSkip: Bool) -> Void

    @State private var isRequesting = false
    @State private var didFinish = false

    var body: some View {
        OnboardingStepContainer(
            progressIndex: OnboardingStep.notifications.progressIndex,
            primaryTitle: "Turn On Reminders",
            primaryState: isRequesting ? .loading : .enabled,
            onPrimary: { Task { await enableReminders() } },
            secondaryTitle: "Not now",
            onSecondary: { finish(remindersEnabled: false, didSkip: true) },
            secondaryStyle: .prominent
        ) {
            VStack(spacing: DesignSystem.Spacing.extraLarge) {
                OnboardingNotificationBannerMock(
                    title: Text("Rent due in 3 days", comment: "Onboarding mock notification title"),
                    message: Text("A gentle heads-up, right when it helps.", comment: "Onboarding mock notification body")
                )
                .padding(.top, DesignSystem.Spacing.large)

                VStack(spacing: DesignSystem.Spacing.small) {
                    Text("Get reminded before it’s due", comment: "Onboarding notifications title")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Group {
                        if billCount > 0 {
                            Text(
                                "We’ll remind you before ^[your \(billCount) bill](inflect: true) are due — never after.",
                                comment: "Onboarding notifications subtitle when bills were added"
                            )
                        } else {
                            Text(
                                "We’ll remind you before your bills are due — never after.",
                                comment: "Onboarding notifications subtitle without bills"
                            )
                        }
                    }
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Mirrors `NotificationSettingsModel.handleEnableRemindersTask`, minus the
    /// permission-denied alert — during onboarding a denial just moves on.
    private func enableReminders() async {
        // Entry guard: once the step finished (e.g. "Not now" during the push
        // transition), a late primary tap must not request permission or
        // mutate preferences into a dead flow.
        guard !didFinish, !isRequesting else { return }
        isRequesting = true
        defer { isRequesting = false }

        let status = await notificationCoordinator.currentAuthorizationStatus()
        switch status {
        case .notDetermined:
            let granted = (try? await notificationCoordinator.requestAuthorization()) ?? false
            analytics.capture(.notificationPermissionResponded(granted: granted))
            if granted {
                preferencesStore.setRemindersEnabled(true)
            }
            finish(remindersEnabled: granted, didSkip: false)

        case .authorized, .provisional, .ephemeral:
            preferencesStore.setRemindersEnabled(true)
            finish(remindersEnabled: true, didSkip: false)

        case .denied:
            finish(remindersEnabled: false, didSkip: false)

        @unknown default:
            finish(remindersEnabled: false, didSkip: false)
        }
    }

    /// One-shot completion: the step must never finish twice (a second call
    /// would push a second paywall and duplicate funnel events).
    private func finish(remindersEnabled: Bool, didSkip: Bool) {
        guard !didFinish else { return }
        didFinish = true
        onFinished(remindersEnabled, didSkip)
    }
}

#if DEBUG
#Preview {
    let preview = BilloPreviewContainer.empty()
    OnboardingNotificationsStepView(billCount: 3, onFinished: { _, _ in })
        .environment(preview.notificationCoordinator)
        .environment(preview.preferencesStore)
        .environment(AnalyticsModel())
        .tint(DesignSystem.Color.green)
}
#endif
