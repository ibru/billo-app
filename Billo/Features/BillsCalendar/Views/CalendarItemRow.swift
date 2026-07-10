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
            let destination = CalendarPaymentRouting.destination(for: payment)
            if let destination {
                if usesStackNavigation {
                    NavigationLink(value: destination) {
                        CalendarPaymentRow(payment: payment, customCategories: customCategories)
                            .calendarCardStyle(indicatorColor: DesignSystem.Color.green)
                            .foregroundColor(Color(uiColor: .label))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        onOpen(destination)
                    } label: {
                        CalendarPaymentRow(payment: payment, customCategories: customCategories)
                            .calendarCardStyle(indicatorColor: DesignSystem.Color.green)
                            .foregroundColor(Color(uiColor: .label))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                CalendarPaymentRow(payment: payment, customCategories: customCategories)
                    .calendarCardStyle(indicatorColor: DesignSystem.Color.green)
            }

        case .income(let view):
            // Persisted past rows route to the per-occurrence detail (edit
            // amount / delete just this / delete all). Future computed rows
            // route to the parent income's detail (edit going forward).
            // Orphaned persisted rows (parent income deleted, no nav target)
            // still route to the occurrence so the user can clean them up.
            let destination = incomeDestination(for: view)
            if let destination {
                if usesStackNavigation {
                    NavigationLink(value: destination) {
                        CalendarIncomeBillStyleRow(incomeOccurrence: view)
                            .calendarCardStyle(indicatorColor: DesignSystem.Color.greenIncome)
                            .foregroundColor(Color(uiColor: .label))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        onOpen(destination)
                    } label: {
                        CalendarIncomeBillStyleRow(incomeOccurrence: view)
                            .calendarCardStyle(indicatorColor: DesignSystem.Color.greenIncome)
                            .foregroundColor(Color(uiColor: .label))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                CalendarIncomeBillStyleRow(incomeOccurrence: view)
                    .calendarCardStyle(indicatorColor: DesignSystem.Color.greenIncome)
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

    /// Persisted past rows go to the per-occurrence detail so the user can
    /// edit *just this row's* amount or delete just this occurrence. Future
    /// computed rows go to the parent `Income` (no per-occurrence row yet).
    /// Returns `nil` when there's no navigation target at all.
    private func incomeDestination(for view: IncomeOccurrenceItem) -> HomeDetailDestination? {
        if let occurrenceID = view.occurrenceID {
            return .incomeOccurrence(occurrenceID)
        }
        if let incomeID = view.incomeID {
            return .income(incomeID)
        }
        return nil
    }
}

/// Payment row for the monthly list, styled like a bill card row.
struct CalendarPaymentRow: View {
    let payment: PaymentEntry
    let customCategories: [CustomCategory]

    private var currencyCode: String {
        payment.snapshotCurrencyCode ?? "USD"
    }

    private var formattedAmount: String {
        payment.amount.formatted(.currency(code: currencyCode))
    }

    private var categoryInfo: CategoryDisplayInfo? {
        guard let identifier = payment.snapshotCategoryIdentifier else { return nil }
        return CategoryCatalog.displayInfo(for: identifier, customCategories: customCategories)
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            CalendarDateStamp(date: payment.datePaid)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text(payment.snapshotName ?? String(localized: "Unknown Bill"))
                    .font(.headline.weight(.bold))
                    .foregroundColor(Color(uiColor: .label))

                if let info = categoryInfo {
                    CategoryCaptionLabel(info: info)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.small / 2) {
                Text(payment.amount, format: .currency(code: currencyCode))
                    .font(.subheadline)
                    .foregroundColor(Color(uiColor: .label))

                let occurrenceDateString = payment.occurrenceDate.formatted(.dateTime.month(.abbreviated).day())
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignSystem.Color.green)
                    Text(String(
                        localized: "Paid for \(occurrenceDateString)",
                        comment: "Calendar payment row: paid-for label with occurrence date"
                    ))
                        .foregroundStyle(DesignSystem.Color.green)
                }
                .font(.caption)
            }
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
    let incomeOccurrence: IncomeOccurrenceItem

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
