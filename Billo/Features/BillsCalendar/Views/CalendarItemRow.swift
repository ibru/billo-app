//  Created by Jiri Urbasek on 12/05/25.

import SwiftData
import SwiftUI

struct CalendarItemRow: View {
    let usesStackNavigation: Bool
    let item: CalendarListItem
    let customCategories: [CustomCategory]
    let onOpen: (HomeDetailDestination) -> Void

    var body: some View {
        switch item {
        case .occurrence(let occurrence, let payments):
            if usesStackNavigation {
                NavigationLink(value: HomeDetailDestination.bill(occurrence.bill.persistentModelID)) {
                    CalendarFutureBillRow(
                        occurrence: occurrence,
                        payments: payments,
                        customCategories: customCategories
                    )
                        .calendarCardStyle()
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    onOpen(.bill(occurrence.bill.persistentModelID))
                } label: {
                    CalendarFutureBillRow(
                        occurrence: occurrence,
                        payments: payments,
                        customCategories: customCategories
                    )
                        .calendarCardStyle()
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
        case .pastOccurrence(let display):
            if usesStackNavigation {
                NavigationLink(value: HomeDetailDestination.bill(display.occurrence.bill.persistentModelID)) {
                    CalendarPastBillRow(display: display, customCategories: customCategories)
                        .calendarCardStyle()
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    onOpen(.bill(display.occurrence.bill.persistentModelID))
                } label: {
                    CalendarPastBillRow(display: display, customCategories: customCategories)
                        .calendarCardStyle()
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
        case .income(let incomeOccurrence):
            if usesStackNavigation {
                NavigationLink(value: HomeDetailDestination.income(incomeOccurrence.income.persistentModelID)) {
                    CalendarIncomeRow(incomeOccurrence: incomeOccurrence)
                        .calendarCardStyle()
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    onOpen(.income(incomeOccurrence.income.persistentModelID))
                } label: {
                    CalendarIncomeRow(incomeOccurrence: incomeOccurrence)
                        .calendarCardStyle()
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
        case .todayDivider:
            CalendarTodayDividerRow()
        case .emptyMonth:
            Text("No events this month")
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
        .accessibilityLabel(String(
            localized: "Income: \(incomeOccurrence.name), \(formattedAmount)",
            comment: "Accessibility: calendar income row label (income name, amount)"
        ))
    }
}

private extension View {
    func calendarCardStyle() -> some View {
        self
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DesignSystem.Color.background)
                    .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
            )
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.extraSmall)
    }
}
