//  Created by Jiri Urbasek on 7/10/26.

import Foundation

/// A common-bill template shown as a tappable chip during onboarding quick
/// setup. Tapping a chip opens a small sheet pre-filled with these defaults;
/// icon and color come from the preset's category.
nonisolated struct OnboardingBillPreset: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let category: DefaultCategoryIdentifier
    let defaultAmount: Decimal
    let defaultDueDay: Int

    /// `defaultAmount` is a USD baseline — the UI shows it through
    /// `defaultAmount(for:)`, which rescales it to the user's currency
    /// (see `OnboardingPresetCurrencyScale`).
    static let all: [OnboardingBillPreset] = [
        OnboardingBillPreset(
            id: "rent",
            name: String(localized: "Rent", comment: "Onboarding bill preset"),
            category: .housing,
            defaultAmount: 1200,
            defaultDueDay: 1
        ),
        OnboardingBillPreset(
            id: "mortgage",
            name: String(localized: "Mortgage", comment: "Onboarding bill preset"),
            category: .housing,
            defaultAmount: 1500,
            defaultDueDay: 1
        ),
        OnboardingBillPreset(
            id: "electricity",
            name: String(localized: "Electricity", comment: "Onboarding bill preset"),
            category: .utilities,
            defaultAmount: 90,
            defaultDueDay: 15
        ),
        OnboardingBillPreset(
            id: "water",
            name: String(localized: "Water", comment: "Onboarding bill preset"),
            category: .utilities,
            defaultAmount: 40,
            defaultDueDay: 15
        ),
        OnboardingBillPreset(
            id: "internet",
            name: String(localized: "Internet", comment: "Onboarding bill preset"),
            category: .phoneInternet,
            defaultAmount: 60,
            defaultDueDay: 20
        ),
        OnboardingBillPreset(
            id: "phone",
            name: String(localized: "Phone", comment: "Onboarding bill preset"),
            category: .phoneInternet,
            defaultAmount: 45,
            defaultDueDay: 20
        ),
        OnboardingBillPreset(
            id: "streaming",
            name: String(localized: "Streaming", comment: "Onboarding bill preset"),
            category: .subscriptions,
            defaultAmount: 15,
            defaultDueDay: 10
        ),
        OnboardingBillPreset(
            id: "music",
            name: String(localized: "Music", comment: "Onboarding bill preset"),
            category: .subscriptions,
            defaultAmount: 11,
            defaultDueDay: 10
        ),
        OnboardingBillPreset(
            id: "car_payment",
            name: String(localized: "Car payment", comment: "Onboarding bill preset"),
            category: .loans,
            defaultAmount: 350,
            defaultDueDay: 5
        ),
        OnboardingBillPreset(
            id: "car_insurance",
            name: String(localized: "Car insurance", comment: "Onboarding bill preset"),
            category: .insurance,
            defaultAmount: 120,
            defaultDueDay: 5
        ),
        OnboardingBillPreset(
            id: "health_insurance",
            name: String(localized: "Health insurance", comment: "Onboarding bill preset"),
            category: .insurance,
            defaultAmount: 200,
            defaultDueDay: 1
        ),
        OnboardingBillPreset(
            id: "gym",
            name: String(localized: "Gym", comment: "Onboarding bill preset"),
            category: .health,
            defaultAmount: 30,
            defaultDueDay: 1
        ),
    ]

    /// The next calendar date matching `dayOfMonth`: today or later this month
    /// if the day hasn't passed, otherwise that day next month. Days beyond the
    /// month's length clamp to its last day (31st in February → Feb 28/29).
    static func nextDueDate(dayOfMonth: Int, from today: Date, calendar: Calendar) -> Date {
        let startOfToday = calendar.startOfDay(for: today)

        func clampedDate(inMonthOf reference: Date) -> Date? {
            var components = calendar.dateComponents([.year, .month], from: reference)
            guard
                let firstOfMonth = calendar.date(from: components),
                let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)
            else { return nil }
            components.day = min(max(dayOfMonth, 1), daysInMonth.count)
            return calendar.date(from: components)
        }

        guard let candidate = clampedDate(inMonthOf: startOfToday) else { return startOfToday }
        if candidate >= startOfToday {
            return candidate
        }
        guard
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfToday),
            let nextCandidate = clampedDate(inMonthOf: nextMonth)
        else { return candidate }
        return nextCandidate
    }

    /// Approximate monthly cost of a bill for the setup screen's running
    /// total. One-time bills count once — good enough for a rough figure.
    static func monthlyEquivalent(amount: Decimal, recurrence: RecurrencePreset) -> Decimal {
        switch recurrence {
        case .weekly:
            return amount * 52 / 12
        case .biweekly:
            return amount * 26 / 12
        case .monthly, .none, .custom:
            return amount
        }
    }
}
