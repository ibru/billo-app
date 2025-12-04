//  Created by Jiri Urbasek on 11/26/25.

import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

private enum BillsListAnchor: Hashable {
    case historyToggle
    case paymentHistorySection
    case paymentHistoryLoadTrigger
    case paymentRow(PersistentIdentifier)
    case summarySection
    case billSection(BillSection)
    case billOccurrence(BillOccurrence.OccurrenceID)
}

struct BillsListView: View {
    @Environment(BillsModel.self) private var billsModel
    @Environment(PaymentHistoryModel.self) private var paymentHistoryModel
    @Environment(NotificationCoordinator.self) private var notificationCoordinator
    @Environment(NotificationPreferencesStore.self) private var preferencesStore
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddBill = false
    @State private var showingSettings = false
    @State private var currentVisibleAnchor: BillsListAnchor = .historyToggle
    @State private var isRestoringScroll = false
    @Query(sort: \CustomCategory.name) private var customCategories: [CustomCategory]

    fileprivate static let scrollSpaceName = "BillsListScrollSpace"

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    listContent(proxy: proxy)
                }
                .coordinateSpace(name: BillsListView.scrollSpaceName)
                .onPreferenceChange(VisibleRowPreferenceKey.self, perform: updateVisibleAnchor)
                .onChange(of: currentVisibleAnchor, initial: false) { _, newAnchor in
                    handleAnchorChange(newAnchor)
                }
                .navigationTitle("Bills")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: Bill.self) { bill in
                    BillDetailView(bill: bill)
                        .environment(BillModel(bill: bill, modelContext: modelContext))
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingAddBill = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingAddBill) {
                    BillEditView(mode: .adding)
                        .environment(billsModel)
                }
                .sheet(isPresented: $showingSettings) {
                    NavigationStack {
                        NotificationSettingsView()
                        .environment(
                            NotificationSettingsModel(
                                preferences: preferencesStore,
                                coordinator: notificationCoordinator,
                                openSettingsHandler: {
#if os(iOS)
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
#endif
                                }
                            )
                        )
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showingSettings = false
                                }
                            }
                        }
                    }
                }
                .task {
                    do {
                        try billsModel.refresh()
                    } catch {
                        print("Failed to refresh bills: \(error)")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func listContent(proxy: ScrollViewProxy) -> some View {
        if paymentHistoryModel.isHistoryVisible {
            PaymentHistorySectionView(
                payments: paymentHistoryModel.displayedPayments,
                customCategories: customCategories,
                isLoading: paymentHistoryModel.isLoading,
                hasMorePages: paymentHistoryModel.hasMorePayments
            )
        }

        PaymentHistoryToggleRow(
            isVisible: paymentHistoryModel.isHistoryVisible,
            action: { toggleHistory(with: proxy) }
        )
        .id(BillsListAnchor.historyToggle)
        .trackVisibleRow(id: .historyToggle)

        SummarySectionView(
            overview: billsModel.sections.weeklyOverview,
            totals: billsModel.sections.monthlyTotals
        )
        .id(BillsListAnchor.summarySection)
        .trackVisibleRow(id: .summarySection)

        billSections()
    }

    @ViewBuilder
    private func billSections() -> some View {
        ForEach(BillSection.allCases) { section in
            if let occurrences = billsModel.sections.occurrencesBySection[section], !occurrences.isEmpty {
                Section(section.rawValue) {
                    ForEach(occurrences) { occurrence in
                        NavigationLink(value: occurrence.bill) {
                            BillRowView(occurrence: occurrence, customCategories: customCategories)
                        }
                        .id(BillsListAnchor.billOccurrence(occurrence.id))
                        .trackVisibleRow(id: .billOccurrence(occurrence.id))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                markPaid(occurrence)
                            } label: {
                                Label("Mark Paid", systemImage: "checkmark.circle")
                            }
                            .tint(.green)
                        }
                    }
                }
                .id(BillsListAnchor.billSection(section))
                .trackVisibleRow(id: .billSection(section))
            }
        }
    }

    private func toggleHistory(with proxy: ScrollViewProxy) {
        let anchorToRestore = currentVisibleAnchor

        Task { @MainActor in
            isRestoringScroll = true
            do {
                try await paymentHistoryModel.toggleHistory()
            } catch {
                print("Failed to toggle payment history: \(error)")
            }

            try? await Task.sleep(for: .milliseconds(50))
            let target = adjustedAnchorForRestoration(anchorToRestore)

            var transaction = Transaction()
            transaction.disablesAnimations = true

            withTransaction(transaction) {
                proxy.scrollTo(target, anchor: .top)
            }

            try? await Task.sleep(for: .milliseconds(80))
            isRestoringScroll = false
        }
    }

    private func adjustedAnchorForRestoration(_ anchor: BillsListAnchor) -> BillsListAnchor {
        switch anchor {
        case .paymentHistorySection, .paymentHistoryLoadTrigger, .paymentRow(_):
            return paymentHistoryModel.isHistoryVisible ? anchor : .historyToggle
        default:
            return anchor
        }
    }

    private func updateVisibleAnchor(_ measurements: [VisibleRowMeasurement]) {
        guard !isRestoringScroll else { return }
        guard let candidate = measurements.min(by: { $0.scrollScore < $1.scrollScore }) else { return }

        if candidate.id != currentVisibleAnchor {
            currentVisibleAnchor = candidate.id
        }
    }

    private func handleAnchorChange(_ anchor: BillsListAnchor) {
        guard paymentHistoryModel.isHistoryVisible else { return }
        guard !isRestoringScroll else { return }

        if anchor == .paymentHistoryLoadTrigger {
            Task { @MainActor in
                guard paymentHistoryModel.hasMorePayments, !paymentHistoryModel.isLoading else { return }
                do {
                    try await paymentHistoryModel.loadNextBatch()
                } catch {
                    print("Failed to load older payments: \(error)")
                }
            }
        }
    }

    private func markPaid(_ occurrence: BillOccurrence) {
        Task {
            do {
                try await billsModel.markPaid(occurrence)
            } catch {
                print("Failed to mark bill as paid: \(error)")
            }
        }
    }
}

private struct PaymentHistoryToggleRow: View {
    let isVisible: Bool
    let action: () -> Void

    var body: some View {
        Section {
            Button(action: action) {
                HStack(spacing: DesignSystem.Spacing.small) {
                    Image(systemName: isVisible ? "chevron.up" : "chevron.down")
                    Text(isVisible ? "Hide Payment History" : "Show Payment History")
                    Spacer()
                }
            }
            .buttonStyle(.borderless)
        }
        .textCase(nil)
    }
}

private struct PaymentHistorySectionView: View {
    let payments: [Payment]
    let customCategories: [CustomCategory]
    let isLoading: Bool
    let hasMorePages: Bool

    var body: some View {
        Section("Payment History") {
            if hasMorePages {
                Color.clear
                    .frame(height: 0.1)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .accessibilityHidden(true)
                    .id(BillsListAnchor.paymentHistoryLoadTrigger)
                    .trackVisibleRow(id: .paymentHistoryLoadTrigger)
            }

            if payments.isEmpty {
                Text("No payments yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DesignSystem.Spacing.small)
            } else {
                ForEach(payments, id: \.persistentModelID) { payment in
                    PaymentRowView(payment: payment, customCategories: customCategories)
                        .id(BillsListAnchor.paymentRow(payment.persistentModelID))
                        .trackVisibleRow(id: .paymentRow(payment.persistentModelID))
                }
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, DesignSystem.Spacing.small)
            }
        }
        .id(BillsListAnchor.paymentHistorySection)
        .trackVisibleRow(id: .paymentHistorySection)
    }
}

private struct SummarySectionView: View {
    let overview: WeeklyOverview
    let totals: MonthlyTotals

    var body: some View {
        Section {
            HStack(spacing: DesignSystem.Spacing.small) {
                CompactWeeklySummary(overview: overview)
                CompactMonthlySummary(totals: totals)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
            )
        }
        .listRowInsets(
            EdgeInsets(
                top: DesignSystem.Spacing.small,
                leading: DesignSystem.Spacing.small,
                bottom: DesignSystem.Spacing.small,
                trailing: DesignSystem.Spacing.small
            )
        )
        .listRowBackground(Color.clear)
    }
}

private struct VisibleRowMeasurement: Equatable {
    let id: BillsListAnchor
    let minY: CGFloat

    var scrollScore: CGFloat {
        minY >= 0 ? minY : abs(minY) + 10_000
    }
}

private struct VisibleRowPreferenceKey: PreferenceKey {
    static var defaultValue: [VisibleRowMeasurement] = []

    static func reduce(value: inout [VisibleRowMeasurement], nextValue: () -> [VisibleRowMeasurement]) {
        value.append(contentsOf: nextValue())
    }
}

private extension View {
    func trackVisibleRow(id: BillsListAnchor) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: VisibleRowPreferenceKey.self,
                    value: [
                        VisibleRowMeasurement(
                            id: id,
                            minY: proxy.frame(in: .named(BillsListView.scrollSpaceName)).minY
                        )
                    ]
                )
            }
        )
    }
}

struct BillRowView: View {
    let occurrence: BillOccurrence
    let customCategories: [CustomCategory]

    private var categoryInfo: CategoryDisplayInfo? {
        CategoryCatalog.displayInfo(for: occurrence.categoryIdentifier, customCategories: customCategories)
    }

    private var timeSpanColor: Color {
        DesignSystem.Color.timeSpanColor(for: occurrence.dueDate, relativeTo: Date(), calendar: .current)
    }

    private var countdown: BillOccurrence.Countdown {
        occurrence.dueCountdown(relativeTo: Date(), calendar: .current)
    }

    private var countdownText: String {
        let parts = countdown.formatted(locale: Locale.current)
        return "\(parts.value)\n\(parts.unit)"
    }

    private var daysUntilDue: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDueDate = calendar.startOfDay(for: occurrence.dueDate)

        return calendar.dateComponents([.day], from: startOfToday, to: startOfDueDate).day ?? 0
    }

    private var isOverdue: Bool {
        daysUntilDue < 0
    }

    private var countdownProgress: Double {
        let remainingMagnitude = min(abs(Double(daysUntilDue)), 30)
        return remainingMagnitude / 30
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            CountdownBadgeView(
                text: countdownText,
                color: timeSpanColor,
                progress: countdownProgress,
                isOverdue: isOverdue
            )

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small / 2) {
                Text(occurrence.name)
                    .font(.headline)
                    .foregroundStyle(timeSpanColor)

                if occurrence.status(relativeTo: Date(), calendar: .current) == .partiallyPaid {
                    Text("Partially paid")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.orange.opacity(0.15))
                        )
                        .foregroundStyle(.orange)
                }

                if let info = categoryInfo {
                    HStack {
                        if let info = categoryInfo {
                            Image(systemName: DesignSystem.Icon.categoryIcon(for: info.iconToken))
                        }
                        Text(info.name)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.small / 2) {
                Text(occurrence.amount, format: .currency(code: occurrence.currencyCode))
                    .font(.headline)
                    .foregroundStyle(timeSpanColor)

                Text(occurrence.dueDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.small / 2)
    }
}

private struct CountdownBadgeView: View {
    let text: String
    let color: Color
    let progress: Double
    let isOverdue: Bool

    private let lineWidth: CGFloat = 3

    var body: some View {
        let clampedProgress = max(0, min(progress, 1))

        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(isOverdue ? 90 : -90))

            Text(text)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 52, height: 52)
    }
}

struct CompactWeeklySummary: View {
    let overview: WeeklyOverview

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small / 2) {
            Text("This Week")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Due:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(overview.dueCount)")
                        .font(.subheadline)
                        .bold()
                }

                HStack {
                    Text("Remaining:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(overview.remainingAmount, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(overview.remainingAmount > 0 ? .orange : .green)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.small)
    }

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
}

struct CompactMonthlySummary: View {
    let totals: MonthlyTotals

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small / 2) {
            Text("This Month")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Due:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(totals.totalDue, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                        .font(.subheadline)
                        .bold()
                }

                HStack {
                    Text("Remaining:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(totals.remaining, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(totals.remaining > 0 ? .red : .green)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.small)
    }

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
}

#Preview("Sample Data") {
    let preview = BilloPreviewContainer.withSampleData()

    return BillsListView()
        .billoPreviewEnvironment(preview)
}

#Preview("Empty State") {
    let preview = BilloPreviewContainer.empty()

    return BillsListView()
        .billoPreviewEnvironment(preview)
}
