//  Created by Jiri Urbasek on 11/26/25.

import SwiftData
import SwiftUI

struct BillsListView: View {
    @Environment(BillsModel.self) private var billsModel
    @Environment(AppSettingsModel.self) private var appSettingsModel
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CustomCategory.name) private var customCategories: [CustomCategory]

    init() { }

    private var currencyCode: String {
        appSettingsModel.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        List {
            SummarySectionView(
                overview: billsModel.sections.weeklyOverview,
                totals: billsModel.sections.monthlyTotals,
                currencyCode: currencyCode
            )
            PaymentHistoryNavigationRow()
                .listRowBackground(Color.clear)

            billSections()
        }
        .listSectionSpacing(0)
        .task {
            do {
                try billsModel.refresh()
            } catch {
                print("Failed to refresh bills: \(error)")
            }
        }
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
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                markPaid(occurrence)
                            } label: {
                                Label("Paid Today", systemImage: "checkmark.circle")
                            }
                            .tint(.green)
                        }
                    }
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

private struct PaymentHistoryNavigationRow: View {
    var body: some View {
        Section {
            NavigationLink(value: AppDestination.paymentHistory) {
                HStack(spacing: DesignSystem.Spacing.small) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text(String(localized: "Payment History"))
                    Spacer()
                }
                .font(.caption)
            }
            NavigationLink(value: AppDestination.incomeList) {
                HStack(spacing: DesignSystem.Spacing.small) {
                    Image(systemName: "banknote")
                        .foregroundStyle(DesignSystem.Color.income)
                    Text(String(localized: "Income"))
                    Spacer()
                }
                .font(.caption)
            }
        }
    }
}

private struct SummarySectionView: View {
    let overview: WeeklyOverview
    let totals: MonthlyTotals
    let currencyCode: String

    var body: some View {
        Section {
            HStack(spacing: DesignSystem.Spacing.small) {
                CompactWeeklySummary(overview: overview, currencyCode: currencyCode)
                CompactMonthlySummary(totals: totals, currencyCode: currencyCode)
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
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Text(occurrence.dueDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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

    @ScaledMetric(relativeTo: .caption) private var lineWidth: CGFloat = 1.5
    @ScaledMetric(relativeTo: .caption) private var padding: CGFloat = 8
    @ScaledMetric(relativeTo: .caption2) private var unitFontSize: CGFloat = 9

    var body: some View {
        let clampedProgress = max(0, min(progress, 1))

        VStack(spacing: -2) {
            Text(numberText)
                .font(.footnote)
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
        .accessibilityLabel("\(numberText) \(unitText)")
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
            Text(section.rawValue.uppercased())
            Spacer()
            if section != .later {
                Text(totalAmount, format: .currency(code: currencyCode))
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .font(.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(sectionColor)
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
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small / 2) {
            Text("This Week")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                if overview.incomeTotal > 0 {
                    HStack {
                        Text("Income:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(overview.incomeTotal, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(DesignSystem.Color.income)
                    }
                }

                HStack {
                    Text("Bills:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(overview.dueAmount, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                        .font(.subheadline)
                        .bold()
                }

                HStack {
                    Text("Net:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(overview.netAmount, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(overview.netAmount >= 0 ? DesignSystem.Color.income : .red)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.small)
    }
}

struct CompactMonthlySummary: View {
    let totals: MonthlyTotals
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small / 2) {
            Text("This Month")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                if totals.incomeTotal > 0 {
                    HStack {
                        Text("Income:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(totals.incomeTotal, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(DesignSystem.Color.income)
                    }
                }

                HStack {
                    Text("Bills:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(totals.totalDue, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                        .font(.subheadline)
                        .bold()
                }

                HStack {
                    Text("Net:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(totals.netAmount, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(totals.netAmount >= 0 ? DesignSystem.Color.income : .red)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.small)
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
