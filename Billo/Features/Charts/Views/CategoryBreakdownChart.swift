//  Created by Jiri Urbasek on 01/21/26.

import SwiftUI
import Charts

struct CategoryBreakdownChart: View {
    let data: CategoryBreakdownData
    var currencyCode: String = Locale.current.currency?.identifier ?? "USD"

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var donutSize: CGFloat {
        horizontalSizeClass == .regular ? 220 : 140
    }

    var body: some View {
        Group {
            if data.slices.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    header

                    emptyState
                }
            } else if horizontalSizeClass == .regular {
                regularChartContent
            } else {
                compactChartContent
            }
        }
        .chartCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        guard !data.slices.isEmpty else {
            return String(
                localized: "Spending by category for \(data.periodLabel). No bills this month.",
                comment: "VoiceOver description for empty category breakdown"
            )
        }

        let totalFormatted = data.total.formatted(.currency(code: currencyCode))
        let categorySummary = data.slices
            .map { "\($0.display.name): \(Int($0.percentage))%" }
            .joined(separator: ", ")

        return String(
            localized: "Spending by category for \(data.periodLabel). Total: \(totalFormatted). \(categorySummary).",
            comment: "VoiceOver description for category breakdown chart"
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
            Text("Spending by Category", comment: "Chart title for category breakdown pie chart")
                .font(.headline)

            Text(data.periodLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        Text("No bills this month", comment: "Empty state for category breakdown when no bills exist")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, DesignSystem.Spacing.large)
    }

    private var compactChartContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            header

            HStack(alignment: .top, spacing: DesignSystem.Spacing.large) {
                donutChart

                compactLegend
            }
        }
    }

    private var regularChartContent: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.large) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                header

                legend
            }

            Spacer(minLength: 0)

            donutChart

            Spacer(minLength: 0)
        }
    }

    private var donutChart: some View {
        Chart(data.slices) { slice in
            SectorMark(
                angle: .value("Amount", slice.amount),
                innerRadius: .ratio(0.5),
                angularInset: 1
            )
            .foregroundStyle(slice.display.color)
        }
        .frame(width: donutSize, height: donutSize)
        .chartLegend(.hidden)
    }

    private var compactLegend: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            ForEach(data.slices) { slice in
                CompactCategoryLegendRow(
                    slice: slice,
                    currencyCode: currencyCode
                )
            }
        }
    }

    private var legend: some View {
        Grid(
            alignment: .leading,
            horizontalSpacing: DesignSystem.Spacing.medium,
            verticalSpacing: DesignSystem.Spacing.small
        ) {
            ForEach(data.slices) { slice in
                CategoryLegendRow(
                    slice: slice,
                    currencyCode: currencyCode
                )
            }
        }
    }
}

private struct CompactCategoryLegendRow: View {
    let slice: CategorySlice
    let currencyCode: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Circle()
                .fill(slice.display.color)
                .frame(width: 10, height: 10)

            Text(slice.display.name)
                .font(.caption)
                .lineLimit(1)

            Spacer(minLength: DesignSystem.Spacing.extraSmall)

            Text(slice.amount, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CategoryLegendRow: View {
    let slice: CategorySlice
    let currencyCode: String

    var body: some View {
        GridRow {
            HStack(spacing: DesignSystem.Spacing.small) {
                Circle()
                    .fill(slice.display.color)
                    .frame(width: 10, height: 10)

                Text(slice.display.name)
                    .font(.caption)
                    .lineLimit(1)
            }

            Text(slice.amount, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                .font(.caption)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
        }
    }
}

#Preview {
    CategoryBreakdownChart(data: CategoryBreakdownData(
        slices: [
            .preview(.housing, amount: 1500, percentage: 45),
            .preview(.subscriptions, amount: 300, percentage: 10),
            .preview(.utilities, amount: 400, percentage: 12)
        ],
        total: 2200,
        periodLabel: "January 2026"
    ))
    .padding()
}

private extension CategorySlice {
    static func preview(
        _ category: DefaultCategoryIdentifier,
        amount: Decimal,
        percentage: Double
    ) -> CategorySlice {
        CategorySlice(
            category: .predefined(category),
            display: CategoryCatalog.displayInfo(for: category),
            amount: amount,
            percentage: percentage
        )
    }
}
