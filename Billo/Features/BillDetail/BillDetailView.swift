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
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(billModel.name)
                    .font(.headline)
                    .lineLimit(1)
                    .opacity(showInlineTitle ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: showInlineTitle)
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
        .confirmationDialog("Delete Bill", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteBill()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this bill and all its payment history?")
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
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            dueBadgeTinted

            dueDateDisplay

            HStack(spacing: DesignSystem.Spacing.extraLarge) {
                VStack(spacing: DesignSystem.Spacing.small) {
                    Text("Amount")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(billModel.amount.formattedAsCurrency(code: billModel.currencyCode))
                        .font(.title2.bold())
                }

                if let categoryInfo = categoryInfo {
                    VStack(spacing: DesignSystem.Spacing.small) {
                        Text("Category")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        HStack(spacing: DesignSystem.Spacing.extraSmall) {
                            Image(systemName: DesignSystem.Icon.categoryIcon(for: categoryInfo.iconToken))
                                .font(.body)
                                .foregroundStyle(DesignSystem.Color.categoryColor(for: categoryInfo.colorToken))

                            Text(categoryInfo.name)
                                .font(.title3.weight(.medium))
                        }
                    }
                }
            }
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

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate("EEEE")
        return f
    }()

    @ViewBuilder
    private var dueDateDisplay: some View {
        VStack(spacing: 2) {
            Text(Self.weekdayFormatter.string(from: displayDueDate))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(displayDueDate, format: .dateTime.month(.wide).day())
                .font(.title.bold())

            Text(displayDueDate, format: .dateTime.year())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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
                .tint(.red)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous))
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
            VStack(spacing: 0) {
                if let recurrenceDescription = billModel.recurrenceDescription {
                    infoRow(label: "Repeats", value: recurrenceDescription, isLast: !hasNotes && !hasAccount && !hasURL)
                }

                if let notes = billModel.notes, !notes.isEmpty {
                    infoRow(label: "Notes", value: notes, isLast: !hasAccount && !hasURL)
                }

                if let accountIdentifier = billModel.accountIdentifier, !accountIdentifier.isEmpty {
                    infoRow(label: "Account ID", value: accountIdentifier, isLast: !hasURL)
                }

                if let providerURL = billModel.providerURL, !providerURL.isEmpty {
                    if let url = URL(string: providerURL) {
                        linkRow(label: "Provider", url: url, displayText: providerURL)
                    } else {
                        infoRow(label: "Provider", value: providerURL, isLast: true)
                    }
                }
            }
            .background(DesignSystem.Color.background)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous))
        }
    }

    @ViewBuilder
    private func infoRow(label: String, value: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.mediumSmall)

            if !isLast {
                Divider()
                    .padding(.leading, DesignSystem.Spacing.medium)
            }
        }
    }

    @ViewBuilder
    private func linkRow(label: String, url: URL, displayText: String) -> some View {
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
    }

    // MARK: - Helpers

    /// The next unpaid occurrence date for display. Falls back to the bill's
    /// base due date for non-recurring bills or when all occurrences are paid.
    private var displayDueDate: Date {
        let calendar = Calendar.current
        let unpaid = bill.unpaidOccurrences(aroundDate: Date(), calendar: calendar)
        return unpaid.first ?? billModel.dueDate
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
    let bill = preview.bills.first ?? Bill(
        name: "Preview Bill",
        amount: 100,
        dueDate: Date()
    )

    return NavigationStack {
        BillDetailView(bill: bill)
            .environment(preview.billModel(for: bill))
            .billoPreviewEnvironment(preview)
    }
}

#Preview("Paid Bill") {
    let preview = BilloPreviewContainer.withSampleData()
    let bill = preview.bills.last ?? Bill(
        name: "Paid Preview",
        amount: 50,
        dueDate: Date()
    )

    return NavigationStack {
        BillDetailView(bill: bill)
            .environment(preview.billModel(for: bill))
            .billoPreviewEnvironment(preview)
    }
}
