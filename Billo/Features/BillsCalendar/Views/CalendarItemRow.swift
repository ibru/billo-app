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
        case .bill(let display):
            let indicatorColor = indicatorColor(for: display)
            if usesStackNavigation {
                NavigationLink(value: HomeDetailDestination.bill(display.occurrence.bill.persistentModelID)) {
                    CalendarBillRow(display: display, customCategories: customCategories)
                        .calendarCardStyle(indicatorColor: indicatorColor)
                        .foregroundColor(Color(uiColor: .label))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    onOpen(.bill(display.occurrence.bill.persistentModelID))
                } label: {
                    CalendarBillRow(display: display, customCategories: customCategories)
                        .calendarCardStyle(indicatorColor: indicatorColor)
                        .foregroundColor(Color(uiColor: .label))
                }
                .buttonStyle(.plain)
            }

        case .payment(let payment):
            if let billID = payment.bill?.persistentModelID {
                if usesStackNavigation {
                    NavigationLink(value: HomeDetailDestination.bill(billID)) {
                        CalendarPaymentRow(payment: payment)
                            .calendarCardStyle(indicatorColor: DesignSystem.Color.green)
                            .foregroundColor(Color(uiColor: .label))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        onOpen(.bill(billID))
                    } label: {
                        CalendarPaymentRow(payment: payment)
                            .calendarCardStyle(indicatorColor: DesignSystem.Color.green)
                            .foregroundColor(Color(uiColor: .label))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                CalendarPaymentRow(payment: payment)
                    .calendarCardStyle(indicatorColor: DesignSystem.Color.green)
            }

        case .income(let incomeOccurrence):
            if usesStackNavigation {
                NavigationLink(value: HomeDetailDestination.income(incomeOccurrence.income.persistentModelID)) {
                    CalendarIncomeBillStyleRow(incomeOccurrence: incomeOccurrence)
                        .calendarCardStyle(indicatorColor: DesignSystem.Color.greenIncome)
                        .foregroundColor(Color(uiColor: .label))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    onOpen(.income(incomeOccurrence.income.persistentModelID))
                } label: {
                    CalendarIncomeBillStyleRow(incomeOccurrence: incomeOccurrence)
                        .calendarCardStyle(indicatorColor: DesignSystem.Color.greenIncome)
                        .foregroundColor(Color(uiColor: .label))
                }
                .buttonStyle(.plain)
            }
        case .todayDivider(let date, _):
            CalendarTodayDividerRow8(date: date)
                .padding(.vertical, -DesignSystem.Spacing.extraSmall)
        case .emptyMonth:
            Text("No events this month")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, DesignSystem.Spacing.medium)
        }
    }

    private func indicatorColor(for display: BillDisplay) -> Color {
        switch display.status {
        case .upcoming:
            return DesignSystem.Color.timeSpanColor(
                for: display.occurrence.dueDate,
                relativeTo: Date(),
                calendar: .current
            )
        case .partiallyPaid:
            return DesignSystem.Color.orange
        case .missed:
            return DesignSystem.Color.red
        }
    }
}

/// Payment row for the monthly list, styled like a bill card row.
struct CalendarPaymentRow: View {
    let payment: PaymentEntry

    private var currencyCode: String {
        payment.snapshotCurrencyCode ?? "USD"
    }

    private var formattedAmount: String {
        payment.amount.formatted(.currency(code: currencyCode))
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            CalendarDateStamp(date: payment.datePaid)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                if let billName = payment.snapshotName {
                    Text(billName)
                        .font(.headline.weight(.bold))
                        .foregroundColor(Color(uiColor: .label))
                } else {
                    Text("Unknown Bill")
                        .font(.headline.weight(.bold))
                        .foregroundColor(Color(uiColor: .label))
                }

                let occurrenceDateString = payment.occurrenceDate.formatted(.dateTime.month(.abbreviated).day())
                Text(String(
                    localized: "Paid for \(occurrenceDateString)",
                    comment: "Calendar payment row: subtitle showing occurrence date"
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(payment.amount, format: .currency(code: currencyCode))
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Color.green)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            localized: "Payment: \(payment.snapshotName ?? "Unknown Bill"), \(formattedAmount)",
            comment: "Accessibility: calendar payment row label (bill name, amount)"
        ))
    }
}

struct CalendarIncomeBillStyleRow: View {
    let incomeOccurrence: IncomeOccurrence

    private var formattedAmount: String {
        incomeOccurrence.amount.formatted(.currency(code: incomeOccurrence.currencyCode))
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            CalendarDateStamp(date: incomeOccurrence.date, accentColor: DesignSystem.Color.greenIncome)

            Image(systemName: "wallet.bifold")
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Color.greenIncome)

            Text(incomeOccurrence.name)
                .font(.headline.weight(.bold))
                .foregroundStyle(DesignSystem.Color.greenIncome)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            HStack(spacing: 0) {
                Text("+")
                Text(incomeOccurrence.amount, format: .currency(code: incomeOccurrence.currencyCode))
            }
            .font(.subheadline)
            .foregroundStyle(DesignSystem.Color.greenIncome)
        }
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
