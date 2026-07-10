//  Created by Jiri Urbasek on 01/21/26.

import SwiftUI
import Charts

struct MonthlyTrendChart: View {
    let data: MonthlyTrendData
    var currencyCode: String = Locale.current.currency?.identifier ?? "USD"

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            header

            if data.points.isEmpty {
                emptyState
            } else {
                chart
            }
        }
        .chartCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        guard !data.points.isEmpty else {
            return String(
                localized: "6-month spending trend. Not enough data yet.",
                comment: "VoiceOver description for empty monthly trend"
            )
        }

        let pointsSummary = data.points
            .map { "\($0.monthLabel): \($0.total.formatted(.currency(code: currencyCode)))" }
            .joined(separator: ", ")

        return String(
            localized: "6-month spending trend. \(pointsSummary).",
            comment: "VoiceOver description for monthly trend chart"
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
            Text("6-Month Trend", comment: "Chart title for monthly spending trend")
                .font(.headline)

            Text("Monthly bill totals", comment: "Subtitle explaining what the trend chart shows")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        Text("Not enough data yet", comment: "Empty state when insufficient data for trend chart")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, DesignSystem.Spacing.large)
    }

    private var chart: some View {
        Chart(data.points) { point in
            BarMark(
                x: .value("Month", point.monthLabel),
                y: .value("Amount", point.total)
            )
            .foregroundStyle(DesignSystem.Color.red.gradient)
        }
        .frame(height: 180)
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
    }
}

#Preview {
    MonthlyTrendChart(data: MonthlyTrendData(
        points: [
            MonthlyTrendPoint(month: Date(), monthLabel: "Aug", total: 2800),
            MonthlyTrendPoint(month: Date(), monthLabel: "Sep", total: 3100),
            MonthlyTrendPoint(month: Date(), monthLabel: "Oct", total: 2900),
            MonthlyTrendPoint(month: Date(), monthLabel: "Nov", total: 3400),
            MonthlyTrendPoint(month: Date(), monthLabel: "Dec", total: 3200),
            MonthlyTrendPoint(month: Date(), monthLabel: "Jan", total: 3000)
        ]
    ))
    .padding()
}
