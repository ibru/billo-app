//  Created by Jiri Urbasek on 12/02/25.

import Foundation

/// Pure functions for building notification content - no side effects
/// Note: Requires @MainActor because String(localized:) requires main actor access
struct NotificationContentBuilder: Sendable {
    let locale: Locale
    let timeZone: TimeZone

    init(locale: Locale = .current, timeZone: TimeZone = .current) {
        self.locale = locale
        self.timeZone = timeZone
    }

    /// Builds reminder body text based on amount and offset
    @MainActor
    func reminderBody(
        amount: Decimal,
        currencyCode: String,
        offsetDays: Int
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"

        switch offsetDays {
        case 0:
            return String(localized: "\(amountString) is due today")
        case 1:
            return String(localized: "\(amountString) is due tomorrow")
        default:
            return String(localized: "\(amountString) is due in \(offsetDays) days")
        }
    }

    struct NotificationDigestItem: Equatable, Sendable {
        let name: String
        let amount: Decimal
        let currencyCode: String
        let dueDate: Date

        init(name: String, amount: Decimal, currencyCode: String, dueDate: Date) {
            self.name = name
            self.amount = amount
            self.currencyCode = currencyCode
            self.dueDate = dueDate
        }

        init(_ occurrence: BillOccurrence) {
            self.init(
                name: occurrence.name,
                amount: occurrence.amount,
                currencyCode: occurrence.currencyCode,
                dueDate: occurrence.dueDate
            )
        }
    }

    /// Builds digest title showing how many bills are due in the configured window.
    @MainActor
    func digestTitle(
        billCount: Int,
        lookaheadDays: Int
    ) -> String {
        switch (billCount == 1, lookaheadDays == 1) {
        case (true, true):
            return String(
                localized: "\(billCount) bill due in next \(lookaheadDays) day",
                comment: "Notification digest title (singular bill, singular day)"
            )
        case (true, false):
            return String(
                localized: "\(billCount) bill due in next \(lookaheadDays) days",
                comment: "Notification digest title (singular bill, plural days)"
            )
        case (false, true):
            return String(
                localized: "\(billCount) bills due in next \(lookaheadDays) day",
                comment: "Notification digest title (plural bills, singular day)"
            )
        case (false, false):
            return String(
                localized: "\(billCount) bills due in next \(lookaheadDays) days",
                comment: "Notification digest title (plural bills, plural days)"
            )
        }
    }

    /// Builds digest body listing first N bills (name, amount, due date), then truncates.
    @MainActor
    func digestBody(
        items: [NotificationDigestItem],
        maxLines: Int = 5
    ) -> String {
        guard !items.isEmpty else { return "" }

        let shownItems = Array(items.prefix(maxLines))
        let lines = shownItems.map { item in
            let amountString = formatAmount(amount: item.amount, currencyCode: item.currencyCode)
            let dueDateString = formatDueDate(item.dueDate)
            return "\(item.name) — \(amountString) — \(dueDateString)"
        }

        let remainingCount = items.count - shownItems.count
        if remainingCount > 0 {
            return (lines + [String(localized: "…and \(remainingCount) more")]).joined(separator: "\n")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Formatting

    @MainActor
    private func formatAmount(amount: Decimal, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    @MainActor
    private func formatDueDate(_ dueDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: dueDate)
    }
}
