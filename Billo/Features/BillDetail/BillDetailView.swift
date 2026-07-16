//  Created by Jiri Urbasek on 11/26/25.

import SwiftUI
import SwiftData

struct BillDetailView: View {
    @Environment(BillModel.self) private var billModel
    @Environment(BillsModel.self) private var billsModel
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomCategory.name) private var customCategories: [CustomCategory]

    @State private var showingEditSheet = false
    @State private var showingMarkPaidSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showInlineTitle = false

    let bill: Bill

    var body: some View {
        DeletedModelGuard(
            model: bill,
            notFoundTitle: "Bill Not Found",
            notFoundDescription: "This bill may have been deleted"
        ) {
            content
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.large) {
                billNameTitle

                headerSection

                actionButtons

                additionalInfoSection

                if billModel.recurrenceDescription != nil {
                    BillDetailRecurrenceSection(bill: bill)
                }

                if !billModel.paymentsSortedDescending.isEmpty {
                    BillDetailPaymentHistorySection(bill: bill)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.bottom, DesignSystem.Spacing.extraLarge)
        }
        .coordinateSpace(.named("detailScroll"))
        .background(DesignSystem.Color.groupedBackground)
        .navigationTitle(billModel.name)
        .platformInlineNavigationTitle()
        .analyticsScreen(.billDetail)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(billModel.name)
                    .font(.headline)
                    .lineLimit(1)
                    .opacity(showInlineTitle ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: showInlineTitle)
                    .replayMaskSensitive()
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            BillEditView(mode: .editing(bill))
                .environment(billModel)
                .environment(billsModel)
        }
        .sheet(isPresented: $showingMarkPaidSheet) {
            MarkPaidSheet(bill: bill)
                .environment(billsModel)
        }
    }

    // MARK: - Bill Name Title

    @ViewBuilder
    private var billNameTitle: some View {
        Text(billModel.name)
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
            .replayMaskSensitive()
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            dueBadgeTinted

            BillDetailDueDateStack(date: displayDueDate)

            BillDetailAmountCategoryGrid(
                amount: billModel.amount,
                currencyCode: billModel.currencyCode,
                category: categoryInfo
            )
        }
    }

    private var dueBadgeText: String {
        Self.dueBadgeText(dueDate: displayDueDate, relativeTo: Date(), calendar: .current)
    }

    static func dueBadgeText(dueDate: Date, relativeTo referenceDate: Date, calendar: Calendar) -> String {
        let today = calendar.startOfDay(for: referenceDate)
        let dueDay = calendar.startOfDay(for: dueDate)
        let daysUntilDue = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0

        if daysUntilDue < 0 {
            let count = abs(daysUntilDue)
            if count == 1 {
                return String(localized: "Overdue by 1 day")
            }
            return String(localized: "Overdue by \(count) days")
        } else if daysUntilDue == 0 {
            return String(localized: "Due Today")
        } else if daysUntilDue == 1 {
            return String(localized: "Due Tomorrow")
        } else {
            return String(localized: "Due in \(daysUntilDue) days")
        }
    }

    private var dueBadgeColor: Color {
        DesignSystem.Color.timeSpanColor(
            for: displayDueDate,
            relativeTo: Date(),
            calendar: .current
        )
    }

    @ViewBuilder
    private var dueBadgeTinted: some View {
        Text(dueBadgeText)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(dueBadgeColor)
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.small)
            .frame(maxWidth: .infinity)
            .background(dueBadgeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous))
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: DesignSystem.Spacing.mediumSmall) {
            Button {
                showingMarkPaidSheet = true
            } label: {
                Label("Mark as Paid", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.mediumSmall)
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Color.green)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous))

            HStack(spacing: DesignSystem.Spacing.mediumSmall) {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.small)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous))

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.small)
                }
                .buttonStyle(.bordered)
                .destructiveTint()
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous))
                .confirmationDialog(
                    "Delete Bill",
                    isPresented: $showingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        deleteBill()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Future occurrences will no longer appear. Past payments stay in your history.")
                }
            }
        }
    }

    // MARK: - Additional Info

    @ViewBuilder
    private var additionalInfoSection: some View {
        let hasNotes = billModel.notes?.isEmpty == false
        let hasAccount = billModel.accountIdentifier?.isEmpty == false
        let hasURL = billModel.providerURL?.isEmpty == false
        let hasRecurrence = billModel.recurrenceDescription != nil

        if hasNotes || hasAccount || hasURL || hasRecurrence {
            BillDetailCard {
                if let recurrenceDescription = billModel.recurrenceDescription {
                    BillDetailInfoRow(
                        label: "Repeats",
                        value: recurrenceDescription,
                        isLast: !hasNotes && !hasAccount && !hasURL
                    )
                }

                if let notes = billModel.notes, !notes.isEmpty {
                    BillDetailInfoRow(
                        label: "Notes",
                        value: notes,
                        isLast: !hasAccount && !hasURL
                    )
                }

                if let accountIdentifier = billModel.accountIdentifier, !accountIdentifier.isEmpty {
                    BillDetailInfoRow(
                        label: "Account ID",
                        value: accountIdentifier,
                        isLast: !hasURL
                    )
                }

                if let providerURL = billModel.providerURL, !providerURL.isEmpty {
                    if let url = URL(string: providerURL) {
                        linkRow(label: "Provider", url: url, displayText: providerURL)
                    } else {
                        BillDetailInfoRow(label: "Provider", value: providerURL, isLast: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func linkRow(label: LocalizedStringKey, url: URL, displayText: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Link(displayText, destination: url)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.mediumSmall)
        .replayMaskSensitive()
    }

    // MARK: - Helpers

    /// The next unpaid occurrence date for display. Falls back to the bill's
    /// base due date for non-recurring bills or when all occurrences are paid.
    private var displayDueDate: Date {
        bill.nextDisplayDueDate(referenceDate: Date(), calendar: Calendar.current)
    }

    private var categoryInfo: CategoryDisplayInfo? {
        CategoryCatalog.displayInfo(for: billModel.categoryIdentifier, customCategories: customCategories)
    }

    private func deleteBill() {
        Task {
            do {
                try await billsModel.deleteBill(bill)
                dismiss()
            } catch {
                Logger.log("Failed to delete bill: \(error)", level: .error)
            }
        }
    }
}

// MARK: - Previews

#Preview("Upcoming Bill") {
    let preview = BilloPreviewContainer.withSampleData()
    // Fallback must live in the store — `DeletedModelGuard` renders an
    // uninserted model (modelContext == nil) as "Bill Not Found".
    let bill = preview.bills.first ?? {
        let fallback = Bill(name: "Preview Bill", amount: 100, dueDate: Date())
        preview.context.insert(fallback)
        return fallback
    }()

    return NavigationStack {
        BillDetailView(bill: bill)
            .environment(preview.billModel(for: bill))
            .billoPreviewEnvironment(preview)
    }
}

#Preview("Paid Bill") {
    let preview = BilloPreviewContainer.withSampleData()
    let bill = preview.bills.last ?? {
        let fallback = Bill(name: "Paid Preview", amount: 50, dueDate: Date())
        preview.context.insert(fallback)
        return fallback
    }()

    return NavigationStack {
        BillDetailView(bill: bill)
            .environment(preview.billModel(for: bill))
            .billoPreviewEnvironment(preview)
    }
}
