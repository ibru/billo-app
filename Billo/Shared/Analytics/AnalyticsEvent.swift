//  Created by Jiri Urbasek on 07/10/26.

import Foundation

/// Where a payment-recording interaction originated. "Paid from notification"
/// is a core business metric for a bill-reminder app, so the source is
/// threaded explicitly instead of being inferred.
enum PaymentEventSource: String, Sendable {
    case sheet
    case listSwipe = "list_swipe"
    case calendar
    case notificationAction = "notification_action"
}

/// Analytics event catalog. Names are lowercase space-separated, property
/// keys snake_case. Associated values stay simple value types (no
/// `[String: Any]` payloads) so the enum remains `Sendable`. Category
/// dimensions always carry `CategoryIdentifier.analyticsKey` — never
/// user-entered text. Monetary amounts are deliberately NEVER tracked
/// (too sensitive); only non-amount dimensions like `currency_code`,
/// `is_partial`, or `days_from_due` ship.
enum AnalyticsEvent: Sendable {
    // MARK: Onboarding
    case onboardingStarted
    case onboardingStepContinued(step: String)
    case onboardingCurrencySelected(currencyCode: String)
    /// `outcome` ∈ purchased | dismissed | already_pro | skipped_by_policy.
    case onboardingCompleted(outcome: String)

    // MARK: Paywall
    case paywallShown(context: String)
    case paywallPlanSelected(planId: String, context: String)
    case paywallFreeTrialToggled(enabled: Bool, context: String)
    case paywallPurchaseAttempted(planId: String, context: String)
    case paywallPurchaseSucceeded(planId: String, context: String)
    case paywallPurchaseCancelled(planId: String, context: String)
    case paywallPurchasePending(planId: String, context: String)
    case paywallPurchaseFailed(planId: String, context: String, error: String)
    case paywallRestoreAttempted(context: String)
    case paywallRestoreSucceeded(context: String)
    case paywallRestoreFailed(context: String, error: String)
    case paywallClosed(context: String)
    case ratingPromptRequested

    // MARK: Bills & payments
    case billCreated(
        category: String,
        isRecurring: Bool,
        recurrencePattern: String,
        currencyCode: String,
        hasNotes: Bool,
        hasProviderURL: Bool,
        hasAccount: Bool
    )
    case billUpdated(category: String, isRecurring: Bool, rescheduled: Bool)
    case billDeleted(category: String, isRecurring: Bool, hadPayments: Bool)
    /// `daysFromDue`: negative = paid early, positive = paid late.
    case paymentRecorded(
        source: PaymentEventSource,
        category: String,
        currencyCode: String,
        daysFromDue: Int,
        isPartial: Bool,
        hasConfirmationNumber: Bool
    )
    case paymentUnmarked(category: String)
    case paymentDeleted(category: String)

    // MARK: Income
    case incomeCreated(isRecurring: Bool, recurrencePattern: String, currencyCode: String)
    case incomeUpdated(isRecurring: Bool, recurrencePattern: String, currencyCode: String)
    case incomeDeleted(isRecurring: Bool)
    case incomeOccurrenceSkipped
    case incomeOccurrenceAmountEdited
    case incomeOccurrenceDeleted

    // MARK: Categories & settings
    case customCategoryCreated
    case customCategoryDeleted
    /// `source` ∈ onboarding | settings.
    case currencyChanged(currencyCode: String, source: String)

    // MARK: Notifications
    case notificationPermissionResponded(granted: Bool)
    case notificationRemindersToggled(enabled: Bool)
    case notificationDigestToggled(enabled: Bool)
    case notificationBadgeModeChanged(mode: String)
    /// `field` ∈ reminder_offsets | reminder_time | digest_lookahead | digest_time.
    case notificationScheduleAdjusted(field: String)
    /// `kind` ∈ bill_reminder | daily_digest.
    case notificationOpened(kind: String)
    case notificationDismissed(kind: String)

    // MARK: Navigation
    case viewModeChanged(to: String)
}

extension AnalyticsEvent {
    var name: String {
        switch self {
        case .onboardingStarted: "onboarding started"
        case .onboardingStepContinued: "onboarding step continued"
        case .onboardingCurrencySelected: "onboarding currency selected"
        case .onboardingCompleted: "onboarding completed"

        case .paywallShown: "paywall shown"
        case .paywallPlanSelected: "paywall plan selected"
        case .paywallFreeTrialToggled: "paywall free trial toggled"
        case .paywallPurchaseAttempted: "paywall purchase attempted"
        case .paywallPurchaseSucceeded: "paywall purchase succeeded"
        case .paywallPurchaseCancelled: "paywall purchase cancelled"
        case .paywallPurchasePending: "paywall purchase pending"
        case .paywallPurchaseFailed: "paywall purchase failed"
        case .paywallRestoreAttempted: "paywall restore attempted"
        case .paywallRestoreSucceeded: "paywall restore succeeded"
        case .paywallRestoreFailed: "paywall restore failed"
        case .paywallClosed: "paywall closed"
        case .ratingPromptRequested: "rating prompt requested"

        case .billCreated: "bill created"
        case .billUpdated: "bill updated"
        case .billDeleted: "bill deleted"
        case .paymentRecorded: "payment recorded"
        case .paymentUnmarked: "payment unmarked"
        case .paymentDeleted: "payment deleted"

        case .incomeCreated: "income created"
        case .incomeUpdated: "income updated"
        case .incomeDeleted: "income deleted"
        case .incomeOccurrenceSkipped: "income occurrence skipped"
        case .incomeOccurrenceAmountEdited: "income occurrence amount edited"
        case .incomeOccurrenceDeleted: "income occurrence deleted"

        case .customCategoryCreated: "custom category created"
        case .customCategoryDeleted: "custom category deleted"
        case .currencyChanged: "currency changed"

        case .notificationPermissionResponded: "notification permission responded"
        case .notificationRemindersToggled: "notification reminders toggled"
        case .notificationDigestToggled: "notification digest toggled"
        case .notificationBadgeModeChanged: "notification badge mode changed"
        case .notificationScheduleAdjusted: "notification schedule adjusted"
        case .notificationOpened: "notification opened"
        case .notificationDismissed: "notification dismissed"

        case .viewModeChanged: "view mode changed"
        }
    }

    var properties: [String: Any] {
        switch self {
        case .onboardingStarted, .ratingPromptRequested,
             .incomeOccurrenceSkipped, .incomeOccurrenceAmountEdited, .incomeOccurrenceDeleted,
             .customCategoryCreated, .customCategoryDeleted:
            return [:]

        case .onboardingStepContinued(let step):
            return ["step": step]
        case .onboardingCurrencySelected(let currencyCode):
            return ["currency_code": currencyCode]
        case .onboardingCompleted(let outcome):
            return ["outcome": outcome]

        case .paywallShown(let context),
             .paywallRestoreAttempted(let context),
             .paywallRestoreSucceeded(let context),
             .paywallClosed(let context):
            return ["context": context]
        case .paywallPlanSelected(let planId, let context),
             .paywallPurchaseAttempted(let planId, let context),
             .paywallPurchaseSucceeded(let planId, let context),
             .paywallPurchaseCancelled(let planId, let context),
             .paywallPurchasePending(let planId, let context):
            return ["plan_id": planId, "context": context]
        case .paywallPurchaseFailed(let planId, let context, let error):
            return ["plan_id": planId, "context": context, "error": error]
        case .paywallRestoreFailed(let context, let error):
            return ["context": context, "error": error]
        case .paywallFreeTrialToggled(let enabled, let context):
            return ["enabled": enabled, "context": context]

        case .billCreated(
            let category, let isRecurring, let recurrencePattern,
            let currencyCode, let hasNotes, let hasProviderURL, let hasAccount
        ):
            return [
                "category": category,
                "is_recurring": isRecurring,
                "recurrence_pattern": recurrencePattern,
                "currency_code": currencyCode,
                "has_notes": hasNotes,
                "has_provider_url": hasProviderURL,
                "has_account": hasAccount
            ]
        case .billUpdated(let category, let isRecurring, let rescheduled):
            return ["category": category, "is_recurring": isRecurring, "rescheduled": rescheduled]
        case .billDeleted(let category, let isRecurring, let hadPayments):
            return ["category": category, "is_recurring": isRecurring, "had_payments": hadPayments]

        case .paymentRecorded(
            let source, let category, let currencyCode,
            let daysFromDue, let isPartial, let hasConfirmationNumber
        ):
            return [
                "source": source.rawValue,
                "category": category,
                "currency_code": currencyCode,
                "days_from_due": daysFromDue,
                "is_partial": isPartial,
                "has_confirmation_number": hasConfirmationNumber
            ]
        case .paymentUnmarked(let category), .paymentDeleted(let category):
            return ["category": category]

        case .incomeCreated(let isRecurring, let recurrencePattern, let currencyCode),
             .incomeUpdated(let isRecurring, let recurrencePattern, let currencyCode):
            return [
                "is_recurring": isRecurring,
                "recurrence_pattern": recurrencePattern,
                "currency_code": currencyCode
            ]
        case .incomeDeleted(let isRecurring):
            return ["is_recurring": isRecurring]

        case .currencyChanged(let currencyCode, let source):
            return ["currency_code": currencyCode, "source": source]

        case .notificationPermissionResponded(let granted):
            return ["granted": granted]
        case .notificationRemindersToggled(let enabled), .notificationDigestToggled(let enabled):
            return ["enabled": enabled]
        case .notificationBadgeModeChanged(let mode):
            return ["mode": mode]
        case .notificationScheduleAdjusted(let field):
            return ["field": field]
        case .notificationOpened(let kind), .notificationDismissed(let kind):
            return ["kind": kind]

        case .viewModeChanged(let to):
            return ["to": to]
        }
    }
}
