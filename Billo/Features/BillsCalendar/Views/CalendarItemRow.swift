//  Created by Jiri Urbasek on 12/05/25.

import SwiftUI

struct CalendarItemRow: View {
    let item: CalendarListItem
    let customCategories: [CustomCategory]

    var body: some View {
        switch item {
        case .occurrence(let occurrence):
            NavigationLink(value: occurrence.bill) {
                BillRowView(occurrence: occurrence, customCategories: customCategories)
                    .calendarCardStyle()
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .tint(.primary)
        case .payment(let payment):
            NavigationLink {
                PaymentDetailView(payment: payment)
            } label: {
                PaymentRowView(
                    payment: payment,
                    customCategories: customCategories,
                    leadingIconStyle: .checkmark,
                    accentColor: .green,
                    showsChevron: true
                )
                .calendarCardStyle()
            }
            .buttonStyle(.plain)
            .tint(.primary)
        case .emptyMonth:
            Text(String(localized: "No events this month"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, DesignSystem.Spacing.medium)
        }
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
