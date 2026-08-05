//  Created by Jiri Urbasek on 7/10/26.

import SwiftUI
import SwiftData
import UserNotifications

/// Explains the home screen's two views (list and calendar) and the toolbar
/// button that switches them. The miniature embeds the REAL `BillsListView`
/// and `BillsCalendarView` — scaled down and fed from an isolated in-memory
/// store with sample data — so what the user learns here is exactly what the
/// app looks like. The mock toolbar blinks the switch icon before each
/// crossfade to teach the mechanic.
struct OnboardingViewModesStepView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onContinue: () -> Void

    var body: some View {
        OnboardingStepContainer(
            progressIndex: OnboardingStep.viewModes.progressIndex,
            primaryTitle: "Continue",
            onPrimary: onContinue
        ) {
            VStack(spacing: DesignSystem.Spacing.extraLarge) {
                HomeShowcaseView(autoCycles: !reduceMotion)

                VStack(spacing: DesignSystem.Spacing.small) {
                    Text("Two ways to see your bills", comment: "Onboarding view modes title")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text(
                        "See everything as a simple list, or laid out on a calendar. The button in the top corner switches between them anytime.",
                        comment: "Onboarding view modes subtitle"
                    )
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
        // The embedded real views set navigation titles ("Calendar") that
        // would otherwise leak up into the onboarding flow's bar.
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Showcase (real views, miniature scale)

private struct HomeShowcaseView: View {
    let autoCycles: Bool

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Created once in `.task` — deliberately NOT inline in `@State`'s initial
    /// value. That expression re-runs on every `HomeShowcaseView.init` (any
    /// parent re-render), rebuilding the whole SwiftData stack and running
    /// `context.save()` mid-view-update each time — on macOS the notification
    /// permission dialog's reactivation re-render did exactly that and crashed
    /// (EXC_BREAKPOINT) inside the save's didSave notification post.
    @State private var showcase: HomeShowcaseEnvironment?
    @State private var mode: BillsHomeViewMode = .list
    @State private var iconBlinks = false
    @State private var pillZoomsIn = false

    /// The real views render on a phone-sized canvas, then scale down into
    /// the card — keeping layout, typography, and colors pixel-faithful.
    private let canvasSize = CGSize(width: 393, height: 520)

    /// iPad and Mac windows (regular × regular) get a near-full-size
    /// miniature — the iPhone scale reads tiny in those layouts. iPhone
    /// (any compact dimension) keeps the original size.
    private var isExpansiveLayout: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }

    private var scale: CGFloat { isExpansiveLayout ? 0.95 : 0.68 }

    /// The mock toolbar is built from real-size fonts (not the scaled
    /// canvas), so it scales its chrome in step with the content scale.
    private var chromeScale: CGFloat { scale / 0.68 }

    private var nextMode: BillsHomeViewMode {
        mode == .list ? .calendar : .list
    }

    var body: some View {
        VStack(spacing: 0) {
            // Above the content so the zoomed-in pill renders in front of
            // the switching views.
            mockToolbar
                .zIndex(1)

            ZStack {
                if let showcase {
                    scaledDown(BillsListView(usesStackNavigation: false, onAddBill: {}), in: showcase)
                        .opacity(mode == .list ? 1 : 0)
                    scaledDown(BillsCalendarView(usesStackNavigation: false), in: showcase)
                        .opacity(mode == .calendar ? 1 : 0)
                }
            }
            // Reserves the miniature's footprint while the environment is
            // still being created, so the card doesn't jump on first render.
            .frame(
                width: canvasSize.width * scale,
                height: canvasSize.height * scale,
                alignment: .top
            )
        }
        .background(DesignSystem.Color.groupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge))
        .cardShadow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            "Miniature of the home screen switching between a bill list and a calendar",
            comment: "Accessibility label for the onboarding view-modes illustration"
        ))
        .task {
            if showcase == nil {
                showcase = HomeShowcaseEnvironment.shared
            }
            guard autoCycles else { return }
            // Endless demo loop: zoom the toolbar pill in (to the front),
            // blink the switch icon emphatically, crossfade the view beneath
            // it, then zoom back out — "THIS button flips the view."
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.0))
                guard !Task.isCancelled else { return }

                withAnimation(.spring(duration: 0.4, bounce: 0.35)) { pillZoomsIn = true }
                try? await Task.sleep(for: .milliseconds(500))

                for _ in 0..<3 {
                    withAnimation(.easeInOut(duration: 0.16)) { iconBlinks = true }
                    try? await Task.sleep(for: .milliseconds(190))
                    withAnimation(.easeInOut(duration: 0.16)) { iconBlinks = false }
                    try? await Task.sleep(for: .milliseconds(170))
                }
                guard !Task.isCancelled else { return }

                withAnimation(.easeInOut(duration: 0.6)) {
                    mode = nextMode
                }
                try? await Task.sleep(for: .milliseconds(800))

                withAnimation(.spring(duration: 0.4, bounce: 0.2)) { pillZoomsIn = false }
            }
        }
    }

    private func scaledDown(_ view: some View, in showcase: HomeShowcaseEnvironment) -> some View {
        view
            .environment(showcase.billsModel)
            .environment(showcase.appSettingsModel)
            // Isolated noop analytics — the embedded real views apply
            // `.analyticsScreen`, which must not pollute the funnel.
            .environment(AnalyticsModel())
            .environment(showcase.reviewPrompts)
            .modelContainer(showcase.container)
            .frame(width: canvasSize.width, height: canvasSize.height)
            .scaleEffect(scale, anchor: .top)
            .frame(
                width: canvasSize.width * scale,
                height: canvasSize.height * scale,
                alignment: .top
            )
            .allowsHitTesting(false)
    }

    /// Mirrors the real home toolbar: leading more-menu circle, centered
    /// title, and the trailing glass pill whose first icon is the view
    /// switcher — showing the NEXT mode's icon, exactly like
    /// `BillsHomeSwitchView`.
    private var mockToolbar: some View {
        ZStack {
            Text("Bills", comment: "Navigation title shown in the onboarding home-screen miniature")
                .font(.system(size: 15 * chromeScale, weight: .semibold))

            HStack {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11 * chromeScale, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 26 * chromeScale, height: 26 * chromeScale)
                    .background(.background, in: Circle())
                    .subtleShadow()

                Spacer()

                HStack(spacing: DesignSystem.Spacing.medium) {
                    Image(systemName: nextMode.iconName)
                        .font(.system(size: 12 * chromeScale, weight: .semibold))
                        .foregroundStyle(.tint)
                        // Emphatic blink: a big size pulse with an opacity
                        // dip, so the eye lands on the switcher itself.
                        .scaleEffect(iconBlinks ? 1.5 : 1)
                        .opacity(iconBlinks ? 0.35 : 1)
                        .contentTransition(.symbolEffect(.replace))

                    Image(systemName: "plus")
                        .font(.system(size: 12 * chromeScale, weight: .semibold))
                        .foregroundStyle(.tint)
                }
                .padding(.horizontal, DesignSystem.Spacing.mediumSmall)
                .frame(height: 26 * chromeScale)
                .background(.background, in: Capsule())
                .cardShadow()
                // Zooms toward the content (anchored at its trailing edge)
                // and in front of it while the view underneath switches.
                .scaleEffect(pillZoomsIn ? 1.5 : 1, anchor: .topTrailing)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.mediumSmall)
        .padding(.vertical, DesignSystem.Spacing.small)
    }
}

// MARK: - Isolated sample-data environment

/// A self-contained SwiftData stack (in-memory, no CloudKit, noop
/// notifications, noop analytics) seeding a handful of realistic bills and an
/// income, so the embedded real views have something representative to show.
/// Follows the `BilloPreviewContainer` pattern.
///
/// Lives for the PROCESS lifetime via `shared` — deliberately never
/// deallocated. The embedded real views register `@Query` observers
/// (`_SwiftData_SwiftUI.QueryController`) for context-did-save notifications
/// that are NOT scoped to this container: they fire on every save in the
/// process and resolve their context's `container` through a weak reference.
/// When this container deallocated with the step view, a surviving observer
/// force-unwrapped that nil container on the NEXT save anywhere in the app —
/// Billo's #1 production crash (EXC_BREAKPOINT in `ModelContext.container
/// .getter` under `QueryController.didSaveChange`, blaming whatever innocent
/// save ran first, e.g. `BillsModel.deleteIncome`). Keeping the tiny
/// in-memory store alive is the fix; the stale observers then no-op
/// harmlessly. Never let a container whose views used `@Query` deallocate
/// while the process keeps saving elsewhere.
@MainActor
private struct HomeShowcaseEnvironment {
    /// First touch must stay inside `.task` (see `HomeShowcaseView.showcase`):
    /// constructing the stack runs `context.save()` mid-view-update otherwise.
    static let shared = HomeShowcaseEnvironment()

    let container: ModelContainer
    let billsModel: BillsModel
    let appSettingsModel: AppSettingsModel
    /// Isolated like the noop analytics below: the embedded real views read
    /// `ReviewPromptModel` from the environment, and the showcase must never
    /// prompt or persist review state — disabled outright rather than relying
    /// on the miniature's `allowsHitTesting(false)` two layers up.
    let reviewPrompts = ReviewPromptModel(isEnabled: false)

    init() {
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        // Same forced construction as `BilloPreviewContainer`: an in-memory
        // container with a valid schema cannot realistically fail.
        // swiftlint:disable:next force_try
        container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let calendar = Calendar.current
        let now = Date()
        func dueDate(inDays days: Int) -> Date {
            calendar.date(byAdding: .day, value: days, to: now) ?? now
        }
        func monthlyRule(anchoredAt date: Date) -> RecurrenceRule {
            RecurrenceRule(
                pattern: .monthly,
                frequency: 1,
                dayOfMonth: calendar.component(.day, from: date)
            )
        }

        let sampleBills: [(String, Decimal, Int, CategoryIdentifier)] = [
            (String(localized: "Rent", comment: "Onboarding showcase sample bill"), 1200, 1, .predefined(.housing)),
            (String(localized: "Streaming", comment: "Onboarding showcase sample bill"), 15, 4, .predefined(.subscriptions)),
            (String(localized: "Electricity", comment: "Onboarding showcase sample bill"), 90, 9, .predefined(.utilities)),
            (String(localized: "Phone", comment: "Onboarding showcase sample bill"), 45, 14, .predefined(.phoneInternet)),
        ]
        for (name, amount, days, category) in sampleBills {
            let due = dueDate(inDays: days)
            context.insert(Bill(
                name: name,
                amount: amount,
                currencyCode: "USD",
                dueDate: due,
                categoryIdentifier: category,
                recurrenceRule: monthlyRule(anchoredAt: due)
            ))
        }

        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let salary = Income(
            name: String(localized: "Salary", comment: "Onboarding showcase sample income"),
            amount: 3500,
            currencyCode: "USD",
            startDate: startOfMonth,
            recurrenceRule: RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 1)
        )
        context.insert(salary)

        let settings = AppSettings(currencyCode: "USD")
        context.insert(settings)
        try? context.save()

        // Throwaway prefs: the showcase never persists user choices, but a
        // named suite still writes a plist that would survive across
        // launches — wipe the domain on creation so nothing accumulates.
        // (Guarded so a suite-creation failure can never wipe .standard.)
        let suiteName = "onboarding-showcase"
        let showcaseDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        if showcaseDefaults !== UserDefaults.standard {
            showcaseDefaults.removePersistentDomain(forName: suiteName)
        }
        let preferences = NotificationPreferencesStore(userDefaults: showcaseDefaults)
        let coordinator = NotificationCoordinator(
            notificationCenter: ShowcaseNoopNotificationCenter(),
            preferences: preferences
        )
        let bills = BillsModel(
            modelContext: context,
            notificationCoordinator: coordinator,
            notificationPreferences: preferences
        )
        try? bills.refresh()
        billsModel = bills

        appSettingsModel = AppSettingsModel(
            modelContext: context,
            billsModel: bills,
            notificationCoordinator: coordinator
        )
        appSettingsModel.load()
    }
}

@MainActor
private final class ShowcaseNoopNotificationCenter: UNNotificationCenterProtocol {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { false }
    func authorizationStatus() async -> UNAuthorizationStatus { .notDetermined }
    func pendingNotificationRequests() async -> [UNNotificationRequest] { [] }
    func add(_ request: UNNotificationRequest) async throws {}
    func removePendingNotificationRequests(withIdentifiers: [String]) {}
    func removeAllPendingNotificationRequests() {}
    func setBadgeCount(_ count: Int) async throws {}
}

#if DEBUG
#Preview {
    OnboardingViewModesStepView(onContinue: {})
        .tint(DesignSystem.Color.green)
}

#Preview("Reduce Motion (no cycling)") {
    HomeShowcaseView(autoCycles: false)
        .padding()
        .tint(DesignSystem.Color.green)
}
#endif
