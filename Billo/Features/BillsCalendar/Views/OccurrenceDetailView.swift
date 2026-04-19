//  Created by Jiri Urbasek on 04/19/26.

import SwiftData
import SwiftUI

/// Read-only detail view for a single past occurrence whose originating Bill
/// has been deleted. Renders the snapshot captured at payment time plus the
/// payments recorded against it. No editing, no future occurrences.
///
/// Laid out to mirror ``BillDetailView``: same title, status badge, due date
/// stack, amount/category grid, info card, and payment rows. Bill-only
/// concerns (action buttons, recurrence, edit/delete sheets) are simply
/// absent — an archived occurrence can't be mutated.
struct OccurrenceDetailView: View {
    let occurrence: IssuedOccurrence

    @Query(sort: \CustomCategory.name) private var customCategories: [CustomCategory]

    @State private var showInlineTitle = false

    private var currencyCode: String { occurrence.billCurrencyCode }

    private var paymentsSortedDescending: [PaymentEntry] {
        occurrence.safePaymentEntries.sorted { $0.datePaid > $1.datePaid }
    }

    private var categoryInfo: CategoryDisplayInfo? {
        CategoryCatalog.displayInfo(
            for: occurrence.billCategoryIdentifier,
            customCategories: customCategories
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.large) {
                titleSection
                deletedBillBanner
                headerSection
                additionalInfoSection
                paymentsSection
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.bottom, DesignSystem.Spacing.extraLarge)
        }
        .coordinateSpace(.named("detailScroll"))
        .background(DesignSystem.Color.groupedBackground)
        .navigationTitle(occurrence.billName)
        .platformInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(occurrence.billName)
                    .font(.headline)
                    .lineLimit(1)
                    .opacity(showInlineTitle ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: showInlineTitle)
            }
        }
    }

    // MARK: - Title

    @ViewBuilder
    private var titleSection: some View {
        Text(occurrence.billName)
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onChange(of: proxy.frame(in: .named("detailScroll")).maxY, initial: true) { _, maxY in
                            let shouldShow = maxY < 0
                            if shouldShow != showInlineTitle {
                                showInlineTitle = shouldShow
                            }
                        }
                }
            )
    }

    // MARK: - Deleted-bill banner

    @ViewBuilder
    private var deletedBillBanner: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "archivebox")
                .foregroundStyle(.secondary)
            Text("This bill was deleted. Showing saved history only.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background(
            DesignSystem.Color.background,
            in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
        )
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            statusBadge

            BillDetailDueDateStack(date: occurrence.dueDate)

            BillDetailAmountCategoryGrid(
                amount: occurrence.billAmount,
                currencyCode: currencyCode,
                category: categoryInfo
            )
        }
    }

    private struct StatusBadgeContent {
        let text: String
        let tint: Color
    }

    private var statusBadgeContent: StatusBadgeContent {
        if occurrence.isPaid {
            return StatusBadgeContent(
                text: String(localized: "Paid", comment: "Occurrence detail: fully paid status badge"),
                tint: DesignSystem.Color.green
            )
        }
        if occurrence.totalPaid > 0 {
            return StatusBadgeContent(
                text: String(
                    localized: "Partially paid · \(occurrence.remainingBalance.formattedAsCurrency(code: currencyCode)) remaining",
                    comment: "Occurrence detail: partially paid status badge with remaining amount"
                ),
                tint: DesignSystem.Color.orange
            )
        }
        return StatusBadgeContent(
            text: String(localized: "Unpaid", comment: "Occurrence detail: unpaid status badge"),
            tint: DesignSystem.Color.red
        )
    }

    @ViewBuilder
    private var statusBadge: some View {
        let content = statusBadgeContent
        Text(content.text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(content.tint)
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.small)
            .frame(maxWidth: .infinity)
            .background(
                content.tint.opacity(0.12),
                in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
            )
    }

    // MARK: - Info card

    @ViewBuilder
    private var additionalInfoSection: some View {
        let hasNotes = occurrence.billNotes?.isEmpty == false
        let hasAccount = occurrence.billAccountIdentifier?.isEmpty == false

        if hasNotes || hasAccount {
            BillDetailCard {
                if let notes = occurrence.billNotes, !notes.isEmpty {
                    BillDetailInfoRow(
                        label: "Notes",
                        value: notes,
                        isLast: !hasAccount
                    )
                }

                if let accountIdentifier = occurrence.billAccountIdentifier, !accountIdentifier.isEmpty {
                    BillDetailInfoRow(
                        label: "Account ID",
                        value: accountIdentifier,
                        isLast: true
                    )
                }
            }
        }
    }

    // MARK: - Payments

    @ViewBuilder
    private var paymentsSection: some View {
        let payments = paymentsSortedDescending
        if !payments.isEmpty {
            VStack(spacing: 0) {
                BillDetailSectionHeader(title: String(
                    localized: "Payments",
                    comment: "Occurrence detail: payments list section header"
                ))

                BillDetailCard {
                    ForEach(Array(payments.enumerated()), id: \.element.persistentModelID) { index, payment in
                        BillDetailPaymentRow(
                            payment: payment,
                            fallbackCurrencyCode: currencyCode,
                            isLast: index == payments.count - 1
                        )
                    }
                }
            }
        }
    }
}
