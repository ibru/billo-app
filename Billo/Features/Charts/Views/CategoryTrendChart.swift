//  Created by Jiri Urbasek on 01/21/26.

import SwiftUI
import Charts

struct CategoryTrendChart: View {
    let data: CategoryTrendData
    var currencyCode: String = Locale.current.currency?.identifier ?? "USD"

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            header

            if data.points.isEmpty {
                emptyState
            } else {
                chart

                legend
            }
        }
        .chartCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        guard !data.points.isEmpty else {
            return String(
                localized: "Category spending trends. Not enough data yet.",
                comment: "VoiceOver description for empty category trend"
            )
        }

        let categoriesList = data.categories
            .map { $0.displayName }
            .joined(separator: ", ")

        return String(
            localized: "Category spending trends over 6 months. Categories: \(categoriesList).",
            comment: "VoiceOver description for category trend chart"
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
            Text("Category Trends", comment: "Chart title for category spending over time")
                .font(.headline)

            Text("Spending by category over time", comment: "Subtitle explaining what category trend chart shows")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        Text("Not enough data yet", comment: "Empty state when insufficient data for category trend")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, DesignSystem.Spacing.large)
    }

    private var chart: some View {
        Chart(data.points) { point in
            BarMark(
                x: .value("Month", point.monthLabel),
                y: .value("Amount", point.amount)
            )
            .foregroundStyle(colorForCategory(point.category))
        }
        .frame(height: 200)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let decimalValue = value.as(Decimal.self) {
                        Text(decimalValue, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartLegend(.hidden)
    }

    private var legend: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: DesignSystem.Spacing.small) {
            ForEach(data.categories, id: \.rawValue) { category in
                HStack(spacing: DesignSystem.Spacing.extraSmall) {
                    Circle()
                        .fill(colorForCategory(category))
                        .frame(width: 8, height: 8)

                    Text(category.displayName)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
    }

    private func colorForCategory(_ category: CategoryIdentifier) -> Color {
        DesignSystem.Color.categoryColor(for: category.colorToken)
    }
}

#Preview {
    CategoryTrendChart(data: CategoryTrendData(
        points: [
            CategoryTrendPoint(month: Date(), monthLabel: "Oct", category: .predefined(.housing), amount: 1500),
            CategoryTrendPoint(month: Date(), monthLabel: "Oct", category: .predefined(.utilities), amount: 200),
            CategoryTrendPoint(month: Date(), monthLabel: "Nov", category: .predefined(.housing), amount: 1500),
            CategoryTrendPoint(month: Date(), monthLabel: "Nov", category: .predefined(.utilities), amount: 180),
            CategoryTrendPoint(month: Date(), monthLabel: "Dec", category: .predefined(.housing), amount: 1500),
            CategoryTrendPoint(month: Date(), monthLabel: "Dec", category: .predefined(.utilities), amount: 220)
        ],
        categories: [.predefined(.housing), .predefined(.utilities)]
    ))
    .padding()
}
