//  Created by Jiri Urbasek on 07/10/26.

import Testing
import Foundation
@testable import Billo

@MainActor
@Suite("AnalyticsModel")
struct AnalyticsModelTests {

    // MARK: - Screen Tracking

    @Test func whenTrackingScreen_thenForwardsScreenNameToClient() {
        let (sut, spy) = makeSUT()

        sut.screen(.billsList)

        #expect(spy.screenEvents.count == 1)
        #expect(spy.screenEvents[0].name == "Bills List")
    }

    @Test func whenTrackingScreenWithProperties_thenForwardsProperties() {
        let (sut, spy) = makeSUT()

        sut.screen(.paywall, properties: ["context": "first_launch"])

        #expect(spy.screenEvents.count == 1)
        #expect(spy.screenEvents[0].name == "Paywall")
        #expect(spy.screenEvents[0].properties["context"] as? String == "first_launch")
    }

    // MARK: - Event Capture

    @Test func whenCapturingBillCreated_thenSendsExpectedNameAndProperties() {
        let (sut, spy) = makeSUT()

        sut.capture(.billCreated(
            category: "default.utilities",
            isRecurring: true,
            recurrencePattern: "monthly",
            currencyCode: "USD",
            hasNotes: false,
            hasProviderURL: true,
            hasAccount: false
        ))

        #expect(spy.capturedEvents.count == 1)
        #expect(spy.capturedEvents[0].name == "bill created")
        #expect(spy.capturedEvents[0].properties["category"] as? String == "default.utilities")
        #expect(spy.capturedEvents[0].properties["is_recurring"] as? Bool == true)
        #expect(spy.capturedEvents[0].properties["recurrence_pattern"] as? String == "monthly")
        #expect(spy.capturedEvents[0].properties["currency_code"] as? String == "USD")
        #expect(spy.capturedEvents[0].properties["has_notes"] as? Bool == false)
        #expect(spy.capturedEvents[0].properties["has_provider_url"] as? Bool == true)
        #expect(spy.capturedEvents[0].properties["has_account"] as? Bool == false)
    }

    @Test func whenCapturingMoneyRelatedEvents_thenNoAmountPropertyIsEverSent() {
        let (sut, spy) = makeSUT()

        // Amounts are deliberately never tracked — too sensitive.
        sut.capture(.incomeCreated(isRecurring: false, recurrencePattern: "none", currencyCode: "EUR"))
        sut.capture(.billCreated(
            category: "custom", isRecurring: false, recurrencePattern: "none",
            currencyCode: "EUR", hasNotes: false, hasProviderURL: false, hasAccount: false
        ))
        sut.capture(.paymentRecorded(
            source: .sheet, category: "custom", currencyCode: "EUR",
            daysFromDue: 0, isPartial: false, hasConfirmationNumber: false
        ))
        sut.capture(.onboardingSetupCommitted(billCount: 3, hasIncome: true))
        sut.capture(.onboardingBillPresetAdded(category: "default.housing"))

        for event in spy.capturedEvents {
            #expect(event.properties["amount"] == nil, "\(event.name) must not carry an amount")
        }
    }

    @Test func whenCapturingPaymentRecorded_thenSendsSourceAndDaysFromDue() {
        let (sut, spy) = makeSUT()

        sut.capture(.paymentRecorded(
            source: .notificationAction,
            category: "custom",
            currencyCode: "USD",
            daysFromDue: -2,
            isPartial: false,
            hasConfirmationNumber: true
        ))

        #expect(spy.capturedEvents.count == 1)
        #expect(spy.capturedEvents[0].name == "payment recorded")
        #expect(spy.capturedEvents[0].properties["source"] as? String == "notification_action")
        #expect(spy.capturedEvents[0].properties["days_from_due"] as? Int == -2)
        #expect(spy.capturedEvents[0].properties["is_partial"] as? Bool == false)
        #expect(spy.capturedEvents[0].properties["has_confirmation_number"] as? Bool == true)
    }

    // MARK: - Pro gates

    @Test func whenCapturingProGateHit_thenSendsExpectedNameAndFeature() {
        let (sut, spy) = makeSUT()

        sut.capture(.proGateHit(feature: "bill_limit"))

        #expect(spy.capturedEvents.count == 1)
        #expect(spy.capturedEvents[0].name == "pro gate hit")
        #expect(spy.capturedEvents[0].properties["feature"] as? String == "bill_limit")
    }

    @Test func whenGateOpensPaywall_thenGateFeatureAndPaywallContextShareOneKey() {
        // The funnel joins `pro gate hit` to `paywall shown` on this key —
        // a mismatch would silently break per-gate conversion reporting.
        // Iterates allCases so a future context can't skip this contract.
        let expectedKeys = [
            "first_launch", "bill_limit", "income_limit", "partial_payment", "custom_recurrence", "charts", "data_export",
            "hidden_bills", "hidden_incomes"
        ]

        #expect(PaywallContext.allCases.map(\.analyticsKey) == expectedKeys)
        #expect(PaywallContext.allCases.map(\.id) == expectedKeys)
    }

    // MARK: - Funnel event-name stability (names are the analytics contract)

    @Test func whenCapturingFunnelEvents_thenNamesMatchContract() {
        let expectations: [(AnalyticsEvent, String)] = [
            (.onboardingStarted, "onboarding started"),
            (.onboardingStepContinued(step: "view_modes"), "onboarding step continued"),
            (.onboardingStepSkipped(step: "bill_setup"), "onboarding step skipped"),
            (.onboardingCurrencySelected(currencyCode: "USD"), "onboarding currency selected"),
            (.onboardingBillPresetAdded(category: "default.housing"), "onboarding bill preset added"),
            (.onboardingBillPresetRemoved(category: "default.housing"), "onboarding bill preset removed"),
            (.onboardingSetupCommitted(billCount: 3, hasIncome: true), "onboarding setup committed"),
            (.onboardingSkippedForReturningUser, "onboarding skipped for returning user"),
            (.onboardingCompleted(outcome: "purchased"), "onboarding completed"),
            (.paywallShown(context: "first_launch"), "paywall shown"),
            (.paywallPurchaseSucceeded(planId: "yearly", context: "first_launch"), "paywall purchase succeeded"),
            (.paywallPurchaseCancelled(planId: "weekly", context: "first_launch"), "paywall purchase cancelled"),
            (.paywallRestoreFailed(context: "first_launch", error: "no_purchases_found"), "paywall restore failed"),
            (.proGateHit(feature: "partial_payment"), "pro gate hit"),
            (.notificationOpened(kind: "bill_reminder"), "notification opened"),
            (.viewModeChanged(to: "calendar"), "view mode changed"),
            (.currencyChanged(currencyCode: "EUR", source: "settings"), "currency changed"),
            (.notificationScheduleAdjusted(field: "reminder_offsets"), "notification schedule adjusted"),
            (.notificationBadgeModeChanged(mode: "due_and_overdue"), "notification badge mode changed"),
            (.notificationRemindersToggled(enabled: true), "notification reminders toggled"),
            (.notificationDigestToggled(enabled: false), "notification digest toggled")
        ]

        for (event, expectedName) in expectations {
            #expect(event.name == expectedName)
        }
    }

    @Test func whenCapturingOnboardingSetupEvents_thenSendsExpectedProperties() {
        let (sut, spy) = makeSUT()

        sut.capture(.onboardingSetupCommitted(billCount: 3, hasIncome: true))
        sut.capture(.onboardingBillPresetAdded(category: "default.housing"))
        sut.capture(.onboardingBillPresetRemoved(category: "default.utilities"))
        sut.capture(.onboardingStepSkipped(step: "bill_setup"))

        #expect(spy.capturedEvents[0].properties["bill_count"] as? Int == 3)
        #expect(spy.capturedEvents[0].properties["has_income"] as? Bool == true)
        #expect(spy.capturedEvents[1].properties["category"] as? String == "default.housing")
        #expect(spy.capturedEvents[2].properties["category"] as? String == "default.utilities")
        #expect(spy.capturedEvents[3].properties["step"] as? String == "bill_setup")
    }

    // MARK: - Super Properties

    @Test func whenRegisteringSuperProperties_thenForwardsToClient() {
        let (sut, spy) = makeSUT()

        sut.register(superProperties: ["is_pro": true, "bill_count": 5])

        #expect(spy.registeredProperties["is_pro"] as? Bool == true)
        #expect(spy.registeredProperties["bill_count"] as? Int == 5)
    }

    @Test func whenUnregisteringSuperProperty_thenForwardsKeyToClient() {
        let (sut, spy) = makeSUT()

        sut.unregister(superProperty: "is_pro")

        #expect(spy.unregisteredKeys == ["is_pro"])
    }

    // MARK: - Helpers

    private func makeSUT() -> (AnalyticsModel, AnalyticsClientSpy) {
        let spy = AnalyticsClientSpy()
        let sut = AnalyticsModel(client: spy)
        return (sut, spy)
    }
}

// MARK: - Spy

final class AnalyticsClientSpy: AnalyticsClient, @unchecked Sendable {
    private(set) var capturedEvents: [(name: String, properties: [String: Any])] = []
    private(set) var screenEvents: [(name: String, properties: [String: Any])] = []
    private(set) var registeredProperties: [String: Any] = [:]
    private(set) var unregisteredKeys: [String] = []

    func capture(event: String, properties: [String: Any]) {
        capturedEvents.append((event, properties))
    }

    func screen(name: String, properties: [String: Any]) {
        screenEvents.append((name, properties))
    }

    func register(superProperties: [String: Any]) {
        registeredProperties.merge(superProperties) { _, new in new }
    }

    func unregister(superProperty key: String) {
        unregisteredKeys.append(key)
    }
}
