//  Created by Jiri Urbasek on 12/05/25.

import SwiftUI

struct CalendarItemRow: View {
    let item: CalendarListItem
    let customCategories: [CustomCategory]

    var body: some View {
        switch item {
        case .occurrence(let occurrence, let payments):
            NavigationLink(value: occurrence.bill) {
                CalendarFutureBillRow(
                    occurrence: occurrence,
                    payments: payments,
                    customCategories: customCategories
                )
                    .calendarCardStyle()
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .tint(.primary)
        case .pastOccurrence(let display):
            NavigationLink(value: display.occurrence.bill) {
                CalendarPastBillRow(display: display, customCategories: customCategories)
                    .calendarCardStyle()
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .tint(.primary)
        case .income(let incomeOccurrence):
            NavigationLink(value: incomeOccurrence.income) {
                CalendarIncomeRow(incomeOccurrence: incomeOccurrence)
                    .calendarCardStyle()
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .tint(.primary)
        case .todayDivider:
            CalendarTodayDividerRow()
        case .emptyMonth:
            Text(String(localized: "No events this month"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, DesignSystem.Spacing.medium)
        }
    }
}

private struct CalendarIncomeRow: View {
    let incomeOccurrence: IncomeOccurrence

    private var formattedAmount: String {
        incomeOccurrence.amount.formatted(.currency(code: incomeOccurrence.currencyCode))
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            CalendarDateStamp(date: incomeOccurrence.date)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text(incomeOccurrence.name)
                    .font(.headline)
                    .lineLimit(1)
            }

            Spacer()

            Text(incomeOccurrence.amount, format: .currency(code: incomeOccurrence.currencyCode))
                .font(.headline)
                .foregroundStyle(DesignSystem.Color.income)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Income: \(incomeOccurrence.name), \(formattedAmount)")
    }
}

private extension View {
    func calendarCardStyle() -> some View {
        self
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
            )
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.extraSmall)
    }
}
