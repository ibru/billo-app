//  Created by Jiri Urbasek on 12/29/25.

import SwiftUI
import SwiftData

struct OnboardingFlowView: View {
    @Environment(AppFlowModel.self) private var flow
    @Environment(AppSettingsModel.self) private var appSettingsModel
    @Environment(StoreKitManager.self) private var storeKit
    @Environment(AnalyticsModel.self) private var analytics
    @Environment(BillsModel.self) private var billsModel
    @Environment(NotificationCoordinator.self) private var notificationCoordinator
    @Environment(\.modelContext) private var modelContext

    let paywallPolicy: FirstLaunchPaywallPolicy
    let onFinish: () -> Void

    @State private var path: [OnboardingStep] = []
    @State private var didTrackStart = false
    @State private var setupModel = OnboardingSetupModel()
    @State private var didSetCurrencyLocally = false
    @State private var showingCommitFailedAlert = false
    /// Remembers whether the failed commit came from Continue or Skip so the
    /// alert's recovery paths keep the same funnel intent (a skipper who
    /// retries must not be counted as a continuer).
    @State private var pendingCommitCapturesContinue = true

    /// Production-store queries (BilloApp puts `sharedModelContainer` on the
    /// WindowGroup). CloudKit imports merge into that container and re-fire
    /// these — the reactive returning-user signal.
    @Query private var syncedBills: [Bill]
    @Query private var appSettingsRows: [AppSettings]

    private let returningUserSkipPolicy = ReturningUserSkipPolicy()

    private var firstStep: OnboardingStep { OnboardingStep.activeFlowSteps[0] }
    private var currentStep: OnboardingStep { path.last ?? firstStep }

    var body: some View {
        NavigationStack(path: $path) {
            stepView(for: firstStep)
                .navigationBarBackButtonHidden(true)
                .navigationDestination(for: OnboardingStep.self) { step in
                    stepView(for: step)
                        .navigationBarBackButtonHidden(true)
                }
        }
        .onAppear {
            guard !didTrackStart else { return }
            didTrackStart = true
            analytics.capture(.onboardingStarted)
            evaluateReturningUserSkip()
        }
        .onChange(of: syncedBills.isEmpty) { _, _ in
            evaluateReturningUserSkip()
        }
        .onChange(of: hasSyncedCurrency) { _, _ in
            evaluateReturningUserSkip()
        }
        .alert(
            Text("Couldn’t save your bills", comment: "Onboarding commit failure alert title"),
            isPresented: $showingCommitFailedAlert
        ) {
            Button {
                commitSetupAndAdvance(capturesContinue: pendingCommitCapturesContinue)
            } label: {
                Text("Try Again", comment: "Onboarding commit failure alert retry button")
            }
            Button(role: .cancel) {
                if pendingCommitCapturesContinue {
                    goToNext(after: .income)
                } else {
                    advance(after: .income)
                }
            } label: {
                Text("Continue Anyway", comment: "Onboarding commit failure alert continue button")
            }
        } message: {
            Text(
                "Something went wrong while saving. You can try again, or continue and add your bills later.",
                comment: "Onboarding commit failure alert message"
            )
        }
    }

    // MARK: - Navigation

    private func goToNext(after step: OnboardingStep) {
        // Capture only when navigation actually happened — a swallowed
        // double-tap must not double-count `step continued` in the funnel.
        guard advance(after: step) else { return }
        analytics.capture(.onboardingStepContinued(step: step.analyticsName))
    }

    /// Navigation only — no funnel event. Skip handlers use this directly so a
    /// skipped step isn't also counted as continued. Returns false when the
    /// push was swallowed by the double-tap guard.
    @discardableResult
    private func advance(after step: OnboardingStep) -> Bool {
        guard let next = OnboardingStep.next(after: step) else {
            Logger.log("Onboarding flow finished (no next step)", level: .info)
            onFinish()
            return true
        }
        // Idempotence: a fast double-tap on a Continue button must not push
        // the same step twice.
        guard path.last != next else { return false }
        Logger.log("Onboarding flow step: \(step.rawValue) → \(next.rawValue)", level: .debug)
        path.append(next)
        return true
    }

    // MARK: - Step Views

    @ViewBuilder
    private func stepView(for step: OnboardingStep) -> some View {
        switch step {
        case .painBubbles:
            OnboardingPainBubblesStepView(onContinue: { goToNext(after: .painBubbles) })
                .analyticsScreen(.onboardingPain)

        case .painScattered:
            OnboardingPainScatteredStepView(onContinue: { goToNext(after: .painScattered) })
                .analyticsScreen(.onboardingPain)

        case .empathyStat:
            OnboardingEmpathyStepView(
                trustCard: .stat,
                progressIndex: OnboardingStep.empathyStat.progressIndex,
                onContinue: { goToNext(after: .empathyStat) }
            )
            .analyticsScreen(.onboardingEmpathy)

        case .empathyQuote:
            OnboardingEmpathyStepView(
                trustCard: .quote,
                progressIndex: OnboardingStep.empathyQuote.progressIndex,
                onContinue: { goToNext(after: .empathyQuote) }
            )
            .analyticsScreen(.onboardingEmpathy)

        case .viewModes:
            OnboardingViewModesStepView(onContinue: { goToNext(after: .viewModes) })
                .analyticsScreen(.onboardingViewModes)

        case .incomeNet:
            OnboardingIncomeNetStepView(onContinue: { goToNext(after: .incomeNet) })
                .analyticsScreen(.onboardingIncomeNet)

        case .reminders:
            OnboardingRemindersStepView(onContinue: { goToNext(after: .reminders) })
                .analyticsScreen(.onboardingReminders)

        case .setupIntro:
            OnboardingSetupIntroStepView(onContinue: { goToNext(after: .setupIntro) })
                .analyticsScreen(.onboardingSetupIntro)

        case .currency:
            // Screen tracked inside CurrencyOnboardingView (which this step
            // embeds) — adding it here too would double-count the step.
            OnboardingCurrencyStepView(onContinue: {
                handleCurrencyFinished()
            })
            .onAppear {
                // Must be set BEFORE the user's save can land: the save fires
                // the AppSettings @Query onChange before the step's onSaved
                // callback runs, so flipping this flag only on save would let
                // that onChange evaluate a spurious returning-user skip.
                // Trade-off: a currency-only sync arriving while the user sits
                // on this step won't skip — the bills signal still covers all
                // data-bearing returning users, and the step no longer
                // auto-advances on synced changes (advance is callback-driven).
                didSetCurrencyLocally = true
            }

        case .billSetup:
            OnboardingBillSetupStepView(
                setupModel: setupModel,
                currencyCode: activeCurrencyCode,
                onContinue: { goToNext(after: .billSetup) },
                onSkip: {
                    analytics.capture(.onboardingStepSkipped(step: OnboardingStep.billSetup.analyticsName))
                    advance(after: .billSetup)
                }
            )
            .analyticsScreen(.onboardingBillSetup)

        case .income:
            OnboardingIncomeStepView(
                setupModel: setupModel,
                currencyCode: activeCurrencyCode,
                onContinue: { commitSetupAndAdvance() },
                onSkip: {
                    analytics.capture(.onboardingStepSkipped(step: OnboardingStep.income.analyticsName))
                    setupModel.clearIncome()
                    commitSetupAndAdvance(capturesContinue: false)
                }
            )
            .analyticsScreen(.onboardingIncome)

        case .notifications:
            OnboardingNotificationsStepView(
                billCount: setupModel.billCount,
                onFinished: { remindersEnabled, didSkip in
                    handleNotificationsFinished(remindersEnabled: remindersEnabled, didSkip: didSkip)
                }
            )
            .analyticsScreen(.onboardingNotifications)

        case .paywall:
            PaywallView(
                context: .firstLaunch,
                isDismissible: true,
                dismissOnFinish: false,
                onFinished: handleFirstLaunchPaywallFinished
            )

        case .thankYou:
            PurchaseThankYouView(onContinue: {
                analytics.capture(.onboardingCompleted(outcome: "purchased"))
                onFinish()
            })
            .analyticsScreen(.purchaseThankYou)
        }
    }

    private var activeCurrencyCode: String {
        appSettingsModel.currencyCode ?? AppSettingsModel.defaultCurrency ?? "USD"
    }

    /// CloudKit sync can leave duplicate `AppSettings` rows (see
    /// `AppSettings.getOrCreate`), and the `@Query` is unsorted — so check all
    /// rows rather than trusting `.first`.
    private var hasSyncedCurrency: Bool {
        appSettingsRows.contains { $0.currencyCode != nil }
    }

    // MARK: - Step Handlers

    private func handleCurrencyFinished() {
        guard let currencyCode = appSettingsModel.currencyCode else { return }
        analytics.capture(.onboardingCurrencySelected(currencyCode: currencyCode))
        goToNext(after: .currency)
    }

    /// Saves the drafted bills/income into the production store — the single
    /// commit point, reached from both continue and skip on the income step.
    /// `capturesContinue: false` on the skip path so a skipped step isn't
    /// also counted as continued in the funnel.
    private func commitSetupAndAdvance(capturesContinue: Bool = true) {
        do {
            if let result = try setupModel.commit(into: modelContext, currencyCode: activeCurrencyCode) {
                captureCommitAnalytics(result: result)
                do {
                    try billsModel.refresh()
                } catch {
                    Logger.log("Bills refresh after onboarding commit failed: \(error)", level: .error)
                }
            }
            if capturesContinue {
                goToNext(after: .income)
            } else {
                advance(after: .income)
            }
        } catch {
            Logger.log("Onboarding setup commit failed: \(error)", level: .error)
            pendingCommitCapturesContinue = capturesContinue
            showingCommitFailedAlert = true
        }
    }

    private func captureCommitAnalytics(result: OnboardingSetupModel.CommitResult) {
        analytics.capture(.onboardingSetupCommitted(billCount: result.billCount, hasIncome: result.hasIncome))

        // The commit bypasses BillsModel.addBill/addIncome, so fire the
        // standard creation events here to keep those funnels honest.
        for draft in setupModel.billDrafts {
            analytics.capture(.billCreated(
                category: CategoryIdentifier.predefined(draft.preset.category).analyticsKey,
                isRecurring: draft.recurrence != .none,
                recurrencePattern: analyticsPattern(for: draft.recurrence),
                currencyCode: activeCurrencyCode,
                hasNotes: false,
                hasProviderURL: false,
                hasAccount: false
            ))
        }
        if let incomeDraft = setupModel.incomeDraft {
            analytics.capture(.incomeCreated(
                isRecurring: incomeDraft.cadence != .none,
                recurrencePattern: analyticsPattern(for: incomeDraft.cadence),
                currencyCode: activeCurrencyCode
            ))
        }
    }

    /// Same convention as `BillsModel`: `RecurrenceRule.pattern.rawValue` or "none".
    private func analyticsPattern(for preset: RecurrencePreset) -> String {
        switch preset {
        case .none: "none"
        case .weekly, .biweekly: RepeatIntervalType.weekly.rawValue
        case .monthly, .custom: RepeatIntervalType.monthly.rawValue
        }
    }

    private func handleNotificationsFinished(remindersEnabled: Bool, didSkip: Bool) {
        if remindersEnabled {
            Task { @MainActor in
                // refreshBills: true — the post-commit refresh may have
                // failed (it's logged, not surfaced), and scheduling against
                // a stale bill list would silently skip the new reminders.
                await AppNotificationRefresher().refreshAndReschedule(
                    billsModel: billsModel,
                    coordinator: notificationCoordinator,
                    refreshBills: true
                )
            }
        }
        // "Not now" is a skip, like on the setup steps; a denied permission
        // after tapping the primary button still counts as continued.
        if didSkip {
            analytics.capture(.onboardingStepSkipped(step: OnboardingStep.notifications.analyticsName))
        } else {
            analytics.capture(.onboardingStepContinued(step: OnboardingStep.notifications.analyticsName))
        }
        evaluatePaywall()
    }

    // MARK: - Paywall

    private func evaluatePaywall() {
        Logger.log("Onboarding flow evaluating paywall", level: .info)
        if storeKit.isPro {
            flow.markFirstLaunchPaywallShown()
            analytics.capture(.onboardingCompleted(outcome: "already_pro"))
            onFinish()
            return
        }

        // Paywall removed from onboarding for now — uncomment this block
        // (and `.paywall` in OnboardingStep.activeFlowSteps) to restore it.
//        let shouldShowPaywall = paywallPolicy.shouldShowPaywallAfterOnboarding(
//            entitlementIsPro: storeKit.isPro,
//            didShowFirstLaunchPaywall: flow.didShowFirstLaunchPaywall
//        )
//
//        if shouldShowPaywall {
//            Logger.log("First-launch paywall will be shown", level: .info)
//            guard path.last != .paywall else { return }
//            path.append(.paywall)
//        } else {
//            Logger.log("First-launch paywall skipped by policy", level: .info)
//            analytics.capture(.onboardingCompleted(outcome: "skipped_by_policy"))
//            onFinish()
//        }
        Logger.log("First-launch paywall disabled — completing onboarding", level: .info)
        analytics.capture(.onboardingCompleted(outcome: "paywall_disabled"))
        onFinish()
    }

    private func handleFirstLaunchPaywallFinished(_ result: PaywallResult) {
        flow.markFirstLaunchPaywallShown()

        switch result {
        case .purchased:
            // `onboarding completed(purchased)` fires from the thank-you
            // Continue button — the flow isn't complete yet here.
            Logger.log("First-launch paywall result: purchased", level: .info)
            guard path.last != .thankYou else { return }
            path.append(.thankYou)
        case .dismissed:
            Logger.log("First-launch paywall result: dismissed", level: .info)
            analytics.capture(.onboardingCompleted(outcome: "dismissed"))
            onFinish()
        }
    }

    // MARK: - Returning-user skip

    /// Ends onboarding early when CloudKit-synced data from a previous install
    /// arrives mid-flow. Drafted quick-setup data is deliberately discarded —
    /// committing preset bills for a returning user would duplicate the synced
    /// ones.
    private func evaluateReturningUserSkip() {
        let shouldSkip = returningUserSkipPolicy.shouldSkipOnboarding(
            hasSyncedBills: !syncedBills.isEmpty,
            hasSyncedCurrency: hasSyncedCurrency,
            didSetCurrencyLocally: didSetCurrencyLocally,
            // Own-write feedback only exists through bills — an empty commit
            // (both setup steps skipped) must not suppress the skip.
            didCommitLocalSetup: setupModel.didCommit && setupModel.billCount > 0,
            currentStep: currentStep
        )
        guard shouldSkip else { return }

        Logger.log("Synced data detected mid-onboarding — skipping for returning user", level: .info)
        appSettingsModel.load()
        analytics.capture(.onboardingSkippedForReturningUser)
        flow.markFirstLaunchPaywallShown()
        onFinish()
    }
}

#if DEBUG && targetEnvironment(simulator)
#Preview("Full onboarding flow") {
    let preview = BilloPreviewContainer.empty()
    let flow = AppFlowModel(persistence: AppPersistence(defaults: UserDefaults(suiteName: "preview-first-launch") ?? .standard))
    let storeKit = StoreKitManager()

    return OnboardingFlowView(paywallPolicy: FirstLaunchPaywallPolicy(), onFinish: {})
        .environment(preview.billsModel)
        .environment(preview.notificationCoordinator)
        .environment(preview.preferencesStore)
        .environment(preview.appSettingsModel)
        .environment(flow)
        .environment(storeKit)
        .environment(AnalyticsModel())
        .modelContainer(preview.container)
}
#endif
