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
    private let viewMode: Binding<BillsHomeViewMode>?
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

    init(viewMode: Binding<BillsHomeViewMode>? = nil) {
        self.viewMode = viewMode
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    listContent(proxy: proxy)
                }
                .listSectionSpacing(0)
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
                .toolbarTitleMenu {
                    if let viewMode {
                        Picker("Default view", selection: viewMode) {
                            ForEach(BillsHomeViewMode.allCases) { mode in
                                Label(mode.title, systemImage: mode.iconName).tag(mode)
                            }
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
        .listRowBackground(Color.clear)
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
                Section {
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
                header: {
                    BillSectionHeader(section: section)
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
                .font(.caption)
            }
            .buttonStyle(.borderless)
        }
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

    private var countdownParts: (value: String, unit: String) {
        occurrence
            .dueCountdown(relativeTo: Date(), calendar: .current)
            .formatted(locale: Locale.current)
    }

    private var badgeConfiguration: CountdownBadgeConfiguration {
        CountdownBadgeConfiguration.make(
            for: occurrence,
            today: Date(),
            calendar: .current
        )
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            if badgeConfiguration.isVisible {
                CountdownBadgeView(
                    numberText: countdownParts.value,
                    unitText: countdownParts.unit,
                    color: badgeConfiguration.color,
                    progress: badgeConfiguration.progress,
                    isOverdue: badgeConfiguration.isOverdue
                )
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text(occurrence.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

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
                    .foregroundStyle(.primary)

                Text(occurrence.dueDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.vertical, DesignSystem.Spacing.small)
    }
}

struct CountdownBadgeConfiguration: Equatable {
    let progress: Double
    let isOverdue: Bool
    let isVisible: Bool
    let color: Color

    static func make(
        for occurrence: BillOccurrence,
        today: Date,
        calendar: Calendar
    ) -> CountdownBadgeConfiguration {
        let startOfToday = calendar.startOfDay(for: today)
        let startOfDueDate = calendar.startOfDay(for: occurrence.dueDate)
        let daysUntilDue = calendar.dateComponents([.day], from: startOfToday, to: startOfDueDate).day ?? 0

        let isOverdue = daysUntilDue < 0
        let magnitude = min(abs(Double(daysUntilDue)), 30)
        let progress = magnitude / 30
        let isVisible = daysUntilDue <= 30
        let color = DesignSystem.Color.timeSpanColor(for: occurrence.dueDate, relativeTo: today, calendar: calendar)

        return .init(
            progress: progress,
            isOverdue: isOverdue,
            isVisible: isVisible,
            color: color
        )
    }
}

private struct CountdownBadgeView: View {
    let numberText: String
    let unitText: String
    let color: Color
    let progress: Double
    let isOverdue: Bool

    private let lineWidth: CGFloat = 1.5

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
                .rotationEffect(.degrees(-90))
                .scaleEffect(x: isOverdue ? -1 : 1, y: 1, anchor: .center)

            VStack(spacing: -2) {
                Text(numberText)
//                    .font(.title3)
//                    .fontWeight(.light)
                Text(unitText)
                    .font(.caption2)
                    .fontWeight(.light)
            }
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.7)
        }
        .frame(width: 46, height: 46)
    }
}

private struct BillSectionHeader: View {
    let section: BillSection

    var body: some View {
        Text(section.rawValue.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(color(for: section))
            .textCase(nil)
    }

    private func color(for section: BillSection) -> Color {
        switch section {
        case .overdue, .today:
            return DesignSystem.Color.dueTodayOrOverdue
        case .next7Days:
            return DesignSystem.Color.dueWithin7Days
        case .next30Days:
            return DesignSystem.Color.dueWithin30Days
        case .later:
            return DesignSystem.Color.dueLater
        }
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
