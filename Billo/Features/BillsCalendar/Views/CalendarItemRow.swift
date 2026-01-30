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
            let indicatorColor = indicatorColor(for: occurrence, payments: payments)
            if usesStackNavigation {
                NavigationLink(value: HomeDetailDestination.bill(occurrence.bill.persistentModelID)) {
                    CalendarFutureBillRow(
                        occurrence: occurrence,
                        payments: payments,
                        customCategories: customCategories
                    )
                        .calendarCardStyle(indicatorColor: indicatorColor)
                        .foregroundColor(Color(uiColor: .label))
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
                        .calendarCardStyle(indicatorColor: indicatorColor)
                        .foregroundColor(Color(uiColor: .label))
                }
                .buttonStyle(.plain)
            }
        case .pastOccurrence(let display):
            let indicatorColor = indicatorColor(for: display)
            if usesStackNavigation {
                NavigationLink(value: HomeDetailDestination.bill(display.occurrence.bill.persistentModelID)) {
                    CalendarPastBillRow(display: display, customCategories: customCategories)
                        .calendarCardStyle(indicatorColor: indicatorColor)
                        .foregroundColor(Color(uiColor: .label))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    onOpen(.bill(display.occurrence.bill.persistentModelID))
                } label: {
                    CalendarPastBillRow(display: display, customCategories: customCategories)
                        .calendarCardStyle(indicatorColor: indicatorColor)
                        .foregroundColor(Color(uiColor: .label))
                }
                .buttonStyle(.plain)
            }
        case .income(let incomeOccurrence):
            if usesStackNavigation {
                NavigationLink(value: HomeDetailDestination.income(incomeOccurrence.income.persistentModelID)) {
                    CalendarIncomeCardRow(incomeOccurrence: incomeOccurrence)
                        .foregroundColor(Color(uiColor: .label))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    onOpen(.income(incomeOccurrence.income.persistentModelID))
                } label: {
                    CalendarIncomeCardRow(incomeOccurrence: incomeOccurrence)
                        .foregroundColor(Color(uiColor: .label))
                }
                .buttonStyle(.plain)
            }
        case .todayDivider(let date, _):
            CalendarTodayDividerRow5(date: date)
                .padding(.vertical, -DesignSystem.Spacing.extraSmall)
        case .emptyMonth:
            Text("No events this month")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, DesignSystem.Spacing.medium)
        }
    }

    private func indicatorColor(for occurrence: BillOccurrence, payments: [PaymentEntry]) -> Color {
        // If prepaid, show green
        if !payments.isEmpty {
            return DesignSystem.Color.green
        }
        // Otherwise use time-based urgency color
        return DesignSystem.Color.timeSpanColor(
            for: occurrence.dueDate,
            relativeTo: Date(),
            calendar: .current
        )
    }

    private func indicatorColor(for display: PastBillDisplay) -> Color {
        switch display.status {
        case .paid:
            return DesignSystem.Color.green
        case .partiallyPaid:
            return DesignSystem.Color.orange
        case .missed:
            return DesignSystem.Color.red
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
            CalendarCompactDateStamp(date: incomeOccurrence.date, accentColor: DesignSystem.Color.blue)
            Text(incomeOccurrence.name)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, DesignSystem.Spacing.mediumSmall)
                .padding(.vertical, DesignSystem.Spacing.extraSmall)
                .background(
                    Capsule()
                        .fill(DesignSystem.Color.blue)
                )

            line

            Text(incomeOccurrence.amount, format: .currency(code: incomeOccurrence.currencyCode))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DesignSystem.Color.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background(Color.clear)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            localized: "Income: \(incomeOccurrence.name), \(formattedAmount)",
            comment: "Accessibility: calendar income row label (income name, amount)"
        ))
    }

    private var line: some View {
        Rectangle()
            .fill(DesignSystem.Color.blue.opacity(0.35))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

private struct CalendarIncomeRow2: View {
    let incomeOccurrence: IncomeOccurrence

    private var formattedAmount: String {
        incomeOccurrence.amount.formatted(.currency(code: incomeOccurrence.currencyCode))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(DesignSystem.Color.blue.opacity(0.25))
                .frame(height: 1)

            HStack(spacing: DesignSystem.Spacing.small) {
                CalendarCompactDateStamp(date: incomeOccurrence.date, accentColor: DesignSystem.Color.blue)
                Text(incomeOccurrence.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Color.blue)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, DesignSystem.Spacing.mediumSmall)
                    .padding(.vertical, DesignSystem.Spacing.extraSmall)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Color.background)
                            .overlay(
                                Capsule()
                                    .stroke(DesignSystem.Color.blue.opacity(0.6), lineWidth: 1)
                            )
                    )

                Spacer(minLength: DesignSystem.Spacing.small)

                Text(incomeOccurrence.amount, format: .currency(code: incomeOccurrence.currencyCode))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DesignSystem.Color.blue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            localized: "Income: \(incomeOccurrence.name), \(formattedAmount)",
            comment: "Accessibility: calendar income row label (income name, amount)"
        ))
    }
}

private struct CalendarIncomeRow3: View {
    let incomeOccurrence: IncomeOccurrence

    private var formattedAmount: String {
        incomeOccurrence.amount.formatted(.currency(code: incomeOccurrence.currencyCode))
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            CalendarCompactDateStamp(date: incomeOccurrence.date, accentColor: DesignSystem.Color.blue)
                .padding(.leading, DesignSystem.Spacing.extraSmall)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                HStack(spacing: DesignSystem.Spacing.extraSmall) {
                    // MARK: - Pick one icon for Income row
//                    Image(systemName: "arrow.down.circle.fill")
//                    Image(systemName: "arrow.down.to.line")
//                    Image(systemName: "banknote.fill")
//                    Image(systemName: "wallet.bifold")
//                    Image(systemName: "dollarsign.circle.fill")
//                    Image(systemName: "creditcard")
//                    Image(systemName: "plus.circle.fill")
//                    Image(systemName: "arrow.up.right.circle.fill")
//                    Image(systemName: "diamond.fill")
//                    Image(systemName: "star.fill")
//                        .font(.system(size: 12))
//                        .foregroundStyle(DesignSystem.Color.blue)
                    Text(incomeOccurrence.name)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DesignSystem.Color.blue)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

//                Rectangle()
//                    .fill(DesignSystem.Color.blue.opacity(0.25))
//                    .frame(height: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(incomeOccurrence.amount, format: .currency(code: incomeOccurrence.currencyCode))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DesignSystem.Color.blue)
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            localized: "Income: \(incomeOccurrence.name), \(formattedAmount)",
            comment: "Accessibility: calendar income row label (income name, amount)"
        ))
    }
}

private struct CalendarIncomeRow4: View {
    let incomeOccurrence: IncomeOccurrence

    private var formattedAmount: String {
        incomeOccurrence.amount.formatted(.currency(code: incomeOccurrence.currencyCode))
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.extraSmall) {
            HStack(spacing: DesignSystem.Spacing.small) {
                CalendarCompactDateStamp(date: incomeOccurrence.date, accentColor: DesignSystem.Color.blue)
                Text(incomeOccurrence.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Color.blue)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: DesignSystem.Spacing.small)
                Text(incomeOccurrence.amount, format: .currency(code: incomeOccurrence.currencyCode))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DesignSystem.Color.blue)
            }

            Rectangle()
                .fill(DesignSystem.Color.blue.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            localized: "Income: \(incomeOccurrence.name), \(formattedAmount)",
            comment: "Accessibility: calendar income row label (income name, amount)"
        ))
    }
}

private struct CalendarIncomeRow9: View {
    let incomeOccurrence: IncomeOccurrence

    private var formattedAmount: String {
        incomeOccurrence.amount.formatted(.currency(code: incomeOccurrence.currencyCode))
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.extraSmall) {
            Rectangle()
                .fill(DesignSystem.Color.blue.opacity(0.3))
                .frame(height: 1)
            HStack(spacing: DesignSystem.Spacing.small) {
                CalendarCompactDateStamp(date: incomeOccurrence.date, accentColor: DesignSystem.Color.blue)
                Text(incomeOccurrence.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Color.blue)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: DesignSystem.Spacing.small)
                Text(incomeOccurrence.amount, format: .currency(code: incomeOccurrence.currencyCode))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DesignSystem.Color.blue)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            localized: "Income: \(incomeOccurrence.name), \(formattedAmount)",
            comment: "Accessibility: calendar income row label (income name, amount)"
        ))
    }
}

private struct CalendarIncomeRow5: View {
    let incomeOccurrence: IncomeOccurrence

    private var formattedAmount: String {
        incomeOccurrence.amount.formatted(.currency(code: incomeOccurrence.currencyCode))
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            CalendarCompactDateStamp(date: incomeOccurrence.date, accentColor: DesignSystem.Color.blue)

            ZStack {
                Rectangle()
                    .fill(DesignSystem.Color.blue.opacity(0.25))
                    .frame(height: 1)

                HStack(spacing: DesignSystem.Spacing.small) {
                    Text(incomeOccurrence.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.Color.blue)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, DesignSystem.Spacing.mediumSmall)
                        .padding(.vertical, DesignSystem.Spacing.extraSmall)
                        .background(DesignSystem.Color.background)

                    Spacer(minLength: DesignSystem.Spacing.small)

                    Text(incomeOccurrence.amount, format: .currency(code: incomeOccurrence.currencyCode))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DesignSystem.Color.blue)
                        .padding(.leading, DesignSystem.Spacing.small)
                        .background(DesignSystem.Color.background)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            localized: "Income: \(incomeOccurrence.name), \(formattedAmount)",
            comment: "Accessibility: calendar income row label (income name, amount)"
        ))
    }
}

private struct CalendarIncomeRow6: View {
    let incomeOccurrence: IncomeOccurrence

    private var formattedAmount: String {
        incomeOccurrence.amount.formatted(.currency(code: incomeOccurrence.currencyCode))
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            CalendarCompactDateStamp(date: incomeOccurrence.date, accentColor: DesignSystem.Color.blue)

            Rectangle()
                .fill(DesignSystem.Color.blue)
                .frame(width: 2, height: 18)

            Text(incomeOccurrence.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.Color.blue)
                .lineLimit(1)
                .truncationMode(.tail)

            Capsule()
                .stroke(
                    DesignSystem.Color.blue.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
                .frame(height: 1)

            Text(incomeOccurrence.amount, format: .currency(code: incomeOccurrence.currencyCode))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DesignSystem.Color.blue)
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            localized: "Income: \(incomeOccurrence.name), \(formattedAmount)",
            comment: "Accessibility: calendar income row label (income name, amount)"
        ))
    }
}

private struct CalendarIncomeRow7: View {
    let incomeOccurrence: IncomeOccurrence

    private var formattedAmount: String {
        incomeOccurrence.amount.formatted(.currency(code: incomeOccurrence.currencyCode))
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            CalendarCompactDateStamp(date: incomeOccurrence.date, accentColor: DesignSystem.Color.blue)

            HStack(spacing: DesignSystem.Spacing.extraSmall) {
                Rectangle()
                    .fill(DesignSystem.Color.blue)
                    .frame(width: 3, height: 16)

                Text(incomeOccurrence.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Color.blue)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.trailing, DesignSystem.Spacing.small)
            }
            .padding(.vertical, DesignSystem.Spacing.extraSmall)
            .padding(.leading, DesignSystem.Spacing.extraSmall)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(DesignSystem.Color.blue.opacity(0.12))
            )

            Rectangle()
                .fill(DesignSystem.Color.blue.opacity(0.35))
                .frame(height: 1)

            Text(incomeOccurrence.amount, format: .currency(code: incomeOccurrence.currencyCode))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DesignSystem.Color.blue)
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            localized: "Income: \(incomeOccurrence.name), \(formattedAmount)",
            comment: "Accessibility: calendar income row label (income name, amount)"
        ))
    }
}

struct CalendarIncomeCardRow: View {
    let incomeOccurrence: IncomeOccurrence

    private var formattedAmount: String {
        incomeOccurrence.amount.formatted(.currency(code: incomeOccurrence.currencyCode))
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            CalendarCompactDateStamp(date: incomeOccurrence.date, accentColor: DesignSystem.Color.blue)
                .padding(.leading, DesignSystem.Spacing.extraSmall)

            HStack(spacing: DesignSystem.Spacing.small) {
                Image(systemName: "wallet.bifold")
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Color.blue)
                Text(incomeOccurrence.name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DesignSystem.Color.blue)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(incomeOccurrence.amount, format: .currency(code: incomeOccurrence.currencyCode))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignSystem.Color.blue)
        }
        .padding(.vertical, -DesignSystem.Spacing.extraSmall)
        .calendarCardStyle(indicatorColor: DesignSystem.Color.blue)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            localized: "Income: \(incomeOccurrence.name), \(formattedAmount)",
            comment: "Accessibility: calendar income row label (income name, amount)"
        ))
    }
}

extension View {
    func calendarCardStyle(
        indicatorColor: Color? = nil,
        backgroundColor: Color = DesignSystem.Color.background
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if let color = indicatorColor {
                    Rectangle()
                        .fill(color)
                        .frame(width: DesignSystem.Card.indicatorWidth)
                        .opacity(0.6)
                }

                self
                    .padding(.leading, DesignSystem.Spacing.small)
                    .padding(.trailing, DesignSystem.Spacing.medium)
                    .padding(.vertical, DesignSystem.Spacing.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, DesignSystem.Spacing.extraSmall)
            .background(backgroundColor)

            // Thin divider at the bottom
            Divider()
                .padding(.leading, DesignSystem.Spacing.extraSmall + DesignSystem.Card.indicatorWidth + DesignSystem.Spacing.small)
        }
    }
}

#Preview("Calendar Divider Variants") {
    let calendar = Calendar.current
    let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 29)) ?? Date()
    let income = Income(name: "Salary", amount: 15000, currencyCode: "USD", startDate: date)
    let occurrence = IncomeOccurrence(from: income, on: date)

    return ScrollView {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
            VStack(spacing: DesignSystem.Spacing.extraSmall) {
                CalendarTodayDividerRow(date: date)
                CalendarTodayDividerRow2(date: date)
                CalendarTodayDividerRow3(date: date)
                CalendarTodayDividerRow4(date: date)
                CalendarTodayDividerRow5(date: date)
                CalendarTodayDividerRow6(date: date)
                CalendarTodayDividerRow7(date: date)
                CalendarTodayDividerCardRow(date: date)
            }

            VStack(spacing: DesignSystem.Spacing.extraSmall) {
                CalendarIncomeRow(incomeOccurrence: occurrence)
                CalendarIncomeCardRow(incomeOccurrence: occurrence)
                CalendarIncomeRow2(incomeOccurrence: occurrence)
                CalendarIncomeRow3(incomeOccurrence: occurrence)
                CalendarIncomeRow4(incomeOccurrence: occurrence)
                CalendarIncomeRow5(incomeOccurrence: occurrence)
                CalendarIncomeRow6(incomeOccurrence: occurrence)
                CalendarIncomeRow7(incomeOccurrence: occurrence)
                CalendarIncomeRow9(incomeOccurrence: occurrence)
            }
        }
        .padding(DesignSystem.Spacing.large)
        .background(.gray.opacity(0.2))
    }
}
