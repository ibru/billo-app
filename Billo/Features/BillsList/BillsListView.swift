//  Created by Jiri Urbasek on 11/26/25.

import SwiftData
import SwiftUI

struct BillsListView: View {
    @Environment(BillsModel.self) private var billsModel
    @Environment(AppSettingsModel.self) private var appSettingsModel
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CustomCategory.name) private var customCategories: [CustomCategory]

    @State private var monthsAhead = 3

    private let usesStackNavigation: Bool
    private let onAddBill: () -> Void
    private let onOpen: (HomeDetailDestination) -> Void

    init(
        usesStackNavigation: Bool = true,
        onAddBill: @escaping () -> Void,
        onOpen: @escaping (HomeDetailDestination) -> Void = { _ in }
    ) {
        self.usesStackNavigation = usesStackNavigation
        self.onAddBill = onAddBill
        self.onOpen = onOpen
    }

    private var currencyCode: String {
        appSettingsModel.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if billsModel.bills.isEmpty {
                    BillsEmptyStateView(onAddBill: onAddBill)
                } else {
                    SummarySectionView(
                        overview: billsModel.sections.weeklyOverview,
                        totals: billsModel.sections.monthlyTotals,
                        currencyCode: currencyCode
                    )
                    .replayMaskSensitive()

                    billSections()

                    showMoreButton
                }
            }
        }
        .background(DesignSystem.Color.groupedBackground)
        .analyticsScreen(.billsList)
        .task {
            do {
                try billsModel.refresh(monthsAhead: monthsAhead)
            } catch {
                Logger.log("Failed to refresh bills: \(error)", level: .error)
            }
        }
    }

    @ViewBuilder
    private func billSections() -> some View {
        ForEach(BillSection.allCases) { section in
            if let occurrences = billsModel.sections.occurrencesBySection[section], !occurrences.isEmpty {
                Section {
                    VStack(spacing: 0) {
                        ForEach(occurrences) { occurrence in
                            let isLast = occurrence.id == occurrences.last?.id
                            if usesStackNavigation {
                                NavigationLink(value: HomeDetailDestination.bill(occurrence.bill.persistentModelID)) {
                                    BillRowView(occurrence: occurrence, customCategories: customCategories, section: section)
                                        .listRowStyle(isLast: isLast)
                                        .foregroundColor(Color(uiColor: .label))
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button {
                                    onOpen(.bill(occurrence.bill.persistentModelID))
                                } label: {
                                    BillRowView(occurrence: occurrence, customCategories: customCategories, section: section)
                                        .listRowStyle(isLast: isLast)
                                        .foregroundColor(Color(uiColor: .label))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .background(DesignSystem.Color.background)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous))
                    .padding(.horizontal, DesignSystem.Spacing.mediumSmall)
                } header: {
                    BillSectionHeader(
                        section: section,
                        occurrences: occurrences,
                        currencyCode: currencyCode
                    )
                }
            }
        }
    }

    private var showMoreButton: some View {
        Button {
            monthsAhead += 3
            do {
                try billsModel.refresh(monthsAhead: monthsAhead)
            } catch {
                Logger.log("Failed to load more bills: \(error)", level: .error)
            }
        } label: {
            Label("Show 3 More Months", systemImage: "calendar.badge.plus")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, DesignSystem.Spacing.extraSmall)
                .padding(.vertical, DesignSystem.Spacing.extraSmall / 2)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.medium)
    }

    private func markPaid(_ occurrence: BillOccurrence) {
        Task {
            do {
                try await billsModel.markPaid(occurrence, source: .listSwipe)
            } catch {
                Logger.log("Failed to mark bill as paid: \(error)", level: .error)
            }
        }
    }
}

// MARK: - Row Style

private extension View {
    func listRowStyle(isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            self
                .padding(.horizontal, DesignSystem.Spacing.mediumSmall)
                .padding(.vertical, DesignSystem.Spacing.small)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !isLast {
                Divider()
                    .padding(.leading, DesignSystem.Spacing.medium)
            }
        }
    }
}

// MARK: - Summary Section

private struct SummarySectionView: View {
    let overview: WeeklyOverview
    let totals: MonthlyTotals
    let currencyCode: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            SummaryColumn(
                title: "This Week",
                incomeTotal: overview.incomeTotal,
                billsTotal: overview.dueAmount,
                netAmount: overview.netAmount,
                currencyCode: currencyCode
            )

            Divider()
                .frame(height: 56)

            SummaryColumn(
                title: "This Month",
                incomeTotal: totals.incomeTotal,
                billsTotal: totals.totalDue,
                netAmount: totals.netAmount,
                currencyCode: currencyCode
            )
        }
        .padding(.vertical, DesignSystem.Spacing.mediumSmall)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                .fill(DesignSystem.Color.background)
        )
        .padding(.horizontal, DesignSystem.Spacing.mediumSmall)
        .padding(.vertical, DesignSystem.Spacing.mediumSmall)
    }
}

private struct SummaryColumn: View {
    let title: String
    let incomeTotal: Decimal
    let billsTotal: Decimal
    let netAmount: Decimal
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            Text(LocalizedStringKey(title))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 2) {
                SummaryRow(
                    label: "Income",
                    amount: incomeTotal,
                    currencyCode: currencyCode,
                    color: DesignSystem.Color.greenIncome
                )

                SummaryRow(
                    label: "Bills",
                    amount: billsTotal,
                    currencyCode: currencyCode,
                    color: nil
                )

                SummaryRow(
                    label: "Net",
                    amount: netAmount,
                    currencyCode: currencyCode,
                    color: netAmount >= 0 ? DesignSystem.Color.greenIncome : DesignSystem.Color.red
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.Spacing.mediumSmall)
    }
}

private struct SummaryRow: View {
    let label: String
    let amount: Decimal
    let currencyCode: String
    let color: Color?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.extraSmall) {
            Text(LocalizedStringKey(label))
                .font(.caption)
                .foregroundStyle(.secondary)

            if amount == 0 {
                Text("–")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            } else {
                Text(amount, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color ?? .primary)
            }
        }
    }
}

struct BillRowView: View {
    let occurrence: BillOccurrence
    let customCategories: [CustomCategory]
    var section: BillSection = .later

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

    private var showsCountdownBadge: Bool {
        section != .later && badgeConfiguration.isVisible
    }

    private var categoryColor: Color {
        categoryInfo?.color ?? .secondary
    }

    private var amountColor: Color {
        switch section {
        case .overdue, .today: return DesignSystem.Color.red
        case .next7Days: return DesignSystem.Color.orange
        case .next30Days: return DesignSystem.Color.yellow
        case .later: return Color(uiColor: .label)
        }
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.mediumSmall) {
            if showsCountdownBadge {
                CountdownBadgeView(
                    numberText: countdownParts.value,
                    unitText: countdownParts.unit,
                    color: badgeConfiguration.color,
                    progress: badgeConfiguration.progress,
                    isOverdue: badgeConfiguration.isOverdue
                )
            } else if section == .later, let info = categoryInfo {
                Image(systemName: info.systemImageName)
                    .font(.title2)
                    .foregroundStyle(categoryColor)
                    .frame(minWidth: CountdownBadgeView.estimatedSize, minHeight: CountdownBadgeView.estimatedSize)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text(occurrence.name)
                    .font(.headline)
                    .foregroundColor(Color(uiColor: .label))

                HStack(spacing: DesignSystem.Spacing.small) {
                    if let info = categoryInfo {
                        HStack(spacing: DesignSystem.Spacing.extraSmall) {
                            if section != .later {
                                Image(systemName: info.systemImageName)
                                    .foregroundStyle(categoryColor)
                            }
                            Text(info.name)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    if occurrence.status(relativeTo: Date(), calendar: .current) == .partiallyPaid {
                        Text("Partially paid")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(DesignSystem.Color.orange.opacity(0.15))
                            )
                            .foregroundStyle(DesignSystem.Color.orange)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.small / 2) {
                Text(occurrence.amount, format: .currency(code: occurrence.currencyCode))
                    .font(.subheadline)
                    .foregroundColor(amountColor)

                Text(occurrence.dueDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: CountdownBadgeView.estimatedSize)
        .contentShape(Rectangle())
        .replayMaskSensitive()
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

struct CountdownBadgeView: View {
    /// Approximate rendered size of the badge for layout alignment purposes.
    static let estimatedSize: CGFloat = 36

    let numberText: String
    let unitText: String
    let color: Color
    let progress: Double
    let isOverdue: Bool

    @ScaledMetric(relativeTo: .caption) private var lineWidth: CGFloat = 2
    @ScaledMetric(relativeTo: .caption) private var padding: CGFloat = 10
    @ScaledMetric(relativeTo: .caption2) private var unitFontSize: CGFloat = 10

    var body: some View {
        let clampedProgress = max(0, min(progress, 1))

        VStack(spacing: -2) {
            Text(numberText)
                .font(.callout)
            Text(unitText)
                .font(.system(size: unitFontSize))
                .fontWeight(.light)
        }
        .foregroundStyle(color)
        .multilineTextAlignment(.center)
        .padding(padding)
        .background {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.30), lineWidth: lineWidth)

                Circle()
                    .trim(from: 0, to: clampedProgress)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(x: isOverdue ? -1 : 1, y: 1, anchor: .center)
            }
        }
        .fixedSize()
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(String(
            localized: "\(numberText) \(unitText)",
            comment: "Accessibility: summary ring label (number and unit)"
        ))
    }
}

private struct BillSectionHeader: View {
    let section: BillSection
    let occurrences: [BillOccurrence]
    let currencyCode: String

    var body: some View {
        let sectionColor = color(for: section)
        let totalAmount = occurrences.reduce(Decimal.zero) { partialResult, occurrence in
            partialResult + occurrence.amount
        }

        return HStack(spacing: DesignSystem.Spacing.small) {
            Text(section.displayName)
            Spacer()
            if section != .later {
                HStack(spacing: 0) {
                    Text("-")
                    Text(totalAmount, format: .currency(code: currencyCode))
                }
                .monospacedDigit()
                .fontWeight(.bold)
                .replayMaskSensitive()
            }
        }
        .frame(maxWidth: .infinity)
        .font(.subheadline)
        .fontWeight(.bold)
        .foregroundStyle(sectionColor)
        .textCase(nil)
        .padding(.horizontal, DesignSystem.Spacing.mediumSmall + DesignSystem.Spacing.mediumSmall)
        .padding(.vertical, DesignSystem.Spacing.small)
        .padding(.top, DesignSystem.Spacing.medium)
        .background(DesignSystem.Color.groupedBackground)
    }

    private func color(for section: BillSection) -> Color {
        switch section {
        case .overdue, .today:
            return DesignSystem.Color.red
        case .next7Days:
            return DesignSystem.Color.orange
        case .next30Days:
            return DesignSystem.Color.yellow
        case .later:
            return DesignSystem.Color.neutralDark
        }
    }
}


#Preview("Sample Data") {
    let preview = BilloPreviewContainer.withSampleData()

    return NavigationStack {
        BillsListView(onAddBill: {})
    }
    .billoPreviewEnvironment(preview)
}

#Preview("Empty State") {
    let preview = BilloPreviewContainer.empty()

    return NavigationStack {
        BillsListView(onAddBill: {})
    }
    .billoPreviewEnvironment(preview)
}
