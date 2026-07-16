//  Created by Jiri Urbasek on 05/14/26.

import SwiftData
import SwiftUI

/// Detail / edit view for a single persisted past `IncomeOccurrence`.
///
/// Mirrors `OccurrenceDetailView` (the bill-side equivalent) so the user
/// recognises the pattern: a top banner explaining the row's nature, the
/// occurrence date stack, the frozen amount, then actions. Two scopes of
/// mutation are exposed:
///
/// * **Amount** — `editIncomeOccurrenceAmount`. Mutates only this row's
///   `incomeAmount`. The parent `Income`, all sibling occurrences, and the
///   future projection are untouched.
/// * **Delete this occurrence** — `deleteIncomeOccurrence`. Soft-skip so the
///   materializer cannot recreate it on the next refresh.
/// * **Delete the entire income** — `deleteIncome`. Same path as
///   `IncomeDetailView`'s destructive action.
///
/// "Edit name" is intentionally not exposed here. Names are a parent-Income
/// concept; per-occurrence name corrections aren't a real use case.
struct IncomeOccurrenceDetailView: View {
    let occurrence: IncomeOccurrence

    @Environment(BillsModel.self) private var billsModel
    @Environment(\.dismiss) private var dismiss

    @State private var draftAmount: Decimal
    @State private var isPersistingAmount = false
    @State private var showingDeleteOccurrenceAlert = false
    @State private var showingDeleteIncomeAlert = false
    @State private var lastError: String?

    init(occurrence: IncomeOccurrence) {
        self.occurrence = occurrence
        // `init` runs before `DeletedModelGuard` can intervene, so check the
        // invalidation-safe reads before touching a persisted property — a
        // zombie occurrence (deleted out-of-band) would trap here otherwise.
        let isInvalidated = occurrence.isDeleted || occurrence.modelContext == nil
        _draftAmount = State(initialValue: isInvalidated ? 0 : occurrence.incomeAmount)
    }

    private var currencyCode: String { occurrence.incomeCurrencyCode }
    private var hasAmountChange: Bool { draftAmount != occurrence.incomeAmount }
    private var canSaveAmount: Bool { draftAmount > 0 && hasAmountChange && !isPersistingAmount }

    var body: some View {
        DeletedModelGuard(
            model: occurrence,
            notFoundTitle: "Income Occurrence Not Found",
            notFoundDescription: "This occurrence may have been deleted"
        ) {
            content
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.large) {
                pastIncomeBanner
                headerSection
                amountEditorSection
                if let lastError {
                    errorBanner(message: lastError)
                }
                actionsSection
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.bottom, DesignSystem.Spacing.extraLarge)
        }
        .background(DesignSystem.Color.groupedBackground)
        .navigationTitle(occurrence.incomeName)
        .platformInlineNavigationTitle()
        .analyticsScreen(.incomeOccurrenceDetail)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isPersistingAmount {
                    ProgressView()
                } else {
                    Button(String(localized: "Save")) {
                        Task { await performSaveAmount() }
                    }
                    .disabled(!canSaveAmount)
                }
            }
        }
        .alert(
            String(localized: "Delete this occurrence?", comment: "Income occurrence detail: confirm single-occurrence deletion"),
            isPresented: $showingDeleteOccurrenceAlert
        ) {
            Button(String(localized: "Cancel"), role: .cancel) { }
            Button(String(localized: "Delete"), role: .destructive) {
                Task { await performDeleteOccurrence() }
            }
        } message: {
            Text(
                String(
                    localized: "Removes only this occurrence from your history. The income itself and future occurrences are unchanged.",
                    comment: "Income occurrence detail: explanation for single-occurrence deletion"
                )
            )
        }
        .alert(
            String(localized: "Delete entire income?", comment: "Income occurrence detail: confirm income-wide deletion"),
            isPresented: $showingDeleteIncomeAlert
        ) {
            Button(String(localized: "Cancel"), role: .cancel) { }
            Button(String(localized: "Delete"), role: .destructive) {
                Task { await performDeleteIncome() }
            }
        } message: {
            Text(
                String(
                    localized: "This permanently deletes \"\(occurrence.incomeName)\". Past occurrences are preserved as history; future occurrences will no longer be generated.",
                    comment: "Income occurrence detail: explanation for deleting the parent income"
                )
            )
        }
    }

    // MARK: - Banner

    @ViewBuilder
    private var pastIncomeBanner: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(DesignSystem.Color.greenIncome)
            Text(
                String(
                    localized: "Past income · this occurrence has been recorded",
                    comment: "Income occurrence detail: banner explaining the row is historical"
                )
            )
            .font(.subheadline)
            .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background(
            DesignSystem.Color.greenIncome.opacity(0.12),
            in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
        )
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            BillDetailDueDateStack(date: occurrence.date)
        }
    }

    // MARK: - Amount editor

    @ViewBuilder
    private var amountEditorSection: some View {
        VStack(spacing: 0) {
            BillDetailSectionHeader(title: String(
                localized: "Amount",
                comment: "Income occurrence detail: amount editor section header"
            ))

            BillDetailCard {
                HStack {
                    Text(String(
                        localized: "This occurrence",
                        comment: "Income occurrence detail: label for the editable amount field"
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Spacer()

                    TextField(
                        String(localized: "Amount"),
                        value: $draftAmount,
                        format: .currency(code: currencyCode)
                    )
                    .multilineTextAlignment(.trailing)
                    .platformDecimalKeyboard()
                    .foregroundStyle(DesignSystem.Color.greenIncome)
                    .fontWeight(.semibold)
                }
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.vertical, DesignSystem.Spacing.mediumSmall)
                .replayMaskSensitive()
            }
        }
    }

    // MARK: - Error banner

    @ViewBuilder
    private func errorBanner(message: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignSystem.Color.red)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background(
            DesignSystem.Color.red.opacity(0.12),
            in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
        )
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionsSection: some View {
        VStack(spacing: 0) {
            BillDetailSectionHeader(title: String(
                localized: "Actions",
                comment: "Income occurrence detail: destructive-actions section header"
            ))

            BillDetailCard {
                Button(role: .destructive) {
                    showingDeleteOccurrenceAlert = true
                } label: {
                    HStack {
                        Label(
                            String(localized: "Delete this occurrence"),
                            systemImage: "xmark.circle"
                        )
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .padding(.vertical, DesignSystem.Spacing.mediumSmall)
                }

                Divider()
                    .padding(.leading, DesignSystem.Spacing.medium)

                Button(role: .destructive) {
                    showingDeleteIncomeAlert = true
                } label: {
                    HStack {
                        Label(
                            String(localized: "Delete all occurrences (entire income)"),
                            systemImage: "trash"
                        )
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .padding(.vertical, DesignSystem.Spacing.mediumSmall)
                }
            }
        }
    }

    // MARK: - Side effects

    @MainActor
    private func performSaveAmount() async {
        guard canSaveAmount else { return }
        isPersistingAmount = true
        defer { isPersistingAmount = false }
        do {
            try await billsModel.editIncomeOccurrenceAmount(occurrence, amount: draftAmount)
            lastError = nil
        } catch let error as IncomeValidationError {
            lastError = error.errorDescription
        } catch {
            lastError = error.localizedDescription
        }
    }

    @MainActor
    private func performDeleteOccurrence() async {
        do {
            try await billsModel.deleteIncomeOccurrence(occurrence)
            dismiss()
        } catch {
            lastError = error.localizedDescription
        }
    }

    @MainActor
    private func performDeleteIncome() async {
        guard let parent = occurrence.income else {
            // Already orphaned (income previously deleted); nothing to do.
            dismiss()
            return
        }
        do {
            try await billsModel.deleteIncome(parent)
            dismiss()
        } catch {
            lastError = error.localizedDescription
        }
    }
}

// MARK: - Previews

// Gated together with `IncomeOccurrencePreview` below: #Preview bodies still
// compile in Release (Profile) builds even though they're stripped at link
// time, so they must not reference DEBUG-only symbols outside the flag.
#if DEBUG
#Preview("Persisted March occurrence") {
    let preview = BilloPreviewContainer.withSampleData()
    let occurrence = IncomeOccurrencePreview.makePersistedMarchOccurrence(in: preview)

    return NavigationStack {
        IncomeOccurrenceDetailView(occurrence: occurrence)
    }
    .billoPreviewEnvironment(preview)
}

#Preview("Orphaned occurrence (parent income deleted)") {
    let preview = BilloPreviewContainer.withSampleData()
    let occurrence = IncomeOccurrencePreview.makeOrphanedMarchOccurrence(in: preview)

    return NavigationStack {
        IncomeOccurrenceDetailView(occurrence: occurrence)
    }
    .billoPreviewEnvironment(preview)
}

/// Preview-only factory for `IncomeOccurrence` rows. Kept private to this file
/// (the detail view is the only consumer) and lives behind `#if DEBUG` so
/// release builds can't accidentally call into preview-shaped construction.
private enum IncomeOccurrencePreview {
    @MainActor
    static func makePersistedMarchOccurrence(in preview: BilloPreviewContainer) -> IncomeOccurrence {
        let context = preview.context
        let calendar = Calendar.current
        let march15 = calendar.date(from: DateComponents(year: 2025, month: 3, day: 15)) ?? Date()

        let income = Income(
            name: "Salary",
            amount: 5_000,
            currencyCode: "USD",
            startDate: calendar.date(from: DateComponents(year: 2025, month: 1, day: 15)) ?? Date(),
            recurrenceRule: RecurrenceRule(pattern: .monthly, frequency: 1, dayOfMonth: 15)
        )
        context.insert(income)

        let occurrence = IncomeOccurrence(
            occurrenceKey: OccurrenceKey.make(stableID: income.stableID, date: march15),
            date: march15,
            incomeName: income.name,
            incomeAmount: 5_000,
            incomeCurrencyCode: income.currencyCode,
            income: income
        )
        context.insert(occurrence)
        try? context.save()
        return occurrence
    }

    @MainActor
    static func makeOrphanedMarchOccurrence(in preview: BilloPreviewContainer) -> IncomeOccurrence {
        let context = preview.context
        let calendar = Calendar.current
        let march15 = calendar.date(from: DateComponents(year: 2025, month: 3, day: 15)) ?? Date()

        // Orphan: no parent Income reference — simulates the case where the
        // parent was deleted (.nullify keeps the snapshot row alive).
        let occurrence = IncomeOccurrence(
            occurrenceKey: "deleted-income-stable-id:2025-03-15",
            date: march15,
            incomeName: "Side gig",
            incomeAmount: 750,
            incomeCurrencyCode: "USD",
            income: nil
        )
        context.insert(occurrence)
        try? context.save()
        return occurrence
    }
}
#endif
