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

    /// Builds digest title for upcoming bills or overdue-only state.
    @MainActor
    func digestTitle(
        upcomingCount: Int,
        lookaheadDays: Int,
        overdueCount: Int
    ) -> String {
        guard upcomingCount == 0 else {
            switch (upcomingCount == 1, lookaheadDays == 1) {
            case (true, true):
                return String(
                    localized: "\(upcomingCount) bill due in next \(lookaheadDays) day",
                    comment: "Notification digest title (singular bill, singular day)"
                )
            case (true, false):
                return String(
                    localized: "\(upcomingCount) bill due in next \(lookaheadDays) days",
                    comment: "Notification digest title (singular bill, plural days)"
                )
            case (false, true):
                return String(
                    localized: "\(upcomingCount) bills due in next \(lookaheadDays) day",
                    comment: "Notification digest title (plural bills, singular day)"
                )
            case (false, false):
                return String(
                    localized: "\(upcomingCount) bills due in next \(lookaheadDays) days",
                    comment: "Notification digest title (plural bills, plural days)"
                )
            }
        }

        switch overdueCount == 1 {
        case true:
            return String(localized: "\(overdueCount) bill is overdue")
        case false:
            return String(localized: "\(overdueCount) bills are overdue")
        }
    }

    /// Builds digest body, prioritizing upcoming bills and summarizing overdue if needed.
    @MainActor
    func digestBody(
        upcomingItems: [NotificationDigestItem],
        overdueItems: [NotificationDigestItem],
        maxLines: Int = 5
    ) -> String {
        guard upcomingItems.isEmpty == false || overdueItems.isEmpty == false else { return "" }

        var lines: [String] = []

        if upcomingItems.isEmpty == false {
            let shownUpcoming = Array(upcomingItems.prefix(maxLines))
            lines.append(contentsOf: shownUpcoming.map(formatItem))

            let remainingUpcoming = upcomingItems.count - shownUpcoming.count
            if remainingUpcoming > 0 {
                lines.append(String(localized: "…and \(remainingUpcoming) more"))
            }

            if overdueItems.isEmpty == false {
                lines.append(formatItem(overdueItems[0]))
                let remainingOverdue = overdueItems.count - 1
                if remainingOverdue > 0 {
                    lines.append(overdueSummaryLine(count: remainingOverdue))
                }
            }

            return lines.joined(separator: "\n")
        }

        let shownOverdue = Array(overdueItems.prefix(3))
        lines.append(contentsOf: shownOverdue.map(formatItem))

        let remainingOverdue = overdueItems.count - shownOverdue.count
        if remainingOverdue > 0 {
            lines.append(overdueSummaryLine(count: remainingOverdue))
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

    @MainActor
    private func formatItem(_ item: NotificationDigestItem) -> String {
        let amountString = formatAmount(amount: item.amount, currencyCode: item.currencyCode)
        let dueDateString = formatDueDate(item.dueDate)
        return "\(item.name) — \(amountString) — \(dueDateString)"
    }

    @MainActor
    private func overdueSummaryLine(count: Int) -> String {
        if count == 1 {
            return String(localized: "plus \(count) more bill is overdue")
        }
        return String(localized: "plus \(count) more bills are overdue")
    }
}
