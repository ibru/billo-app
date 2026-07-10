//  Created by Jiri Urbasek on 07/09/26.

import SwiftUI
import Charts

struct PaymentTimingChart: View {
    let data: PaymentTimingData

    private var hasPayments: Bool {
        data.onTimePercentage != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            header

            if hasPayments {
                headline

                chart
            } else {
                emptyState
            }
        }
        .chartCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
            Text("On-Time Payments", comment: "Chart title for payment punctuality statistics")
                .font(.headline)

            Text("Paid date vs. due date, last 6 months", comment: "Subtitle explaining what the payment timing chart shows")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.small) {
            if let percentage = data.onTimePercentage {
                Text("\(Int(percentage.rounded()))%")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(percentage >= 80 ? DesignSystem.Color.greenIncome : DesignSystem.Color.orange)

                Text("paid on time", comment: "Caption following the on-time payment percentage")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if let averageDaysLate = data.averageDaysLate {
                averageTimingBadge(averageDaysLate: averageDaysLate)
            }
        }
    }

    private func averageTimingBadge(averageDaysLate: Double) -> some View {
        let days = Int(abs(averageDaysLate).rounded())
        let text: Text = if averageDaysLate > 0.5 {
            Text("avg. \(days) days late", comment: "Badge showing average payment delay in days")
        } else if averageDaysLate < -0.5 {
            Text("avg. \(days) days early", comment: "Badge showing average payment earliness in days")
        } else {
            Text("avg. right on time", comment: "Badge shown when payments average out to the due date")
        }

        return text
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Chart

    private var chart: some View {
        Chart(data.points) { point in
            BarMark(
                x: .value("Month", point.monthLabel),
                y: .value("Payments", point.onTimeCount)
            )
            .foregroundStyle(by: .value("Status", String(localized: "On time", comment: "Legend label for payments made on or before the due date")))

            BarMark(
                x: .value("Month", point.monthLabel),
                y: .value("Payments", point.lateCount)
            )
            .foregroundStyle(by: .value("Status", String(localized: "Late", comment: "Legend label for payments made after the due date")))
        }
        .chartForegroundStyleScale([
            String(localized: "On time", comment: "Legend label for payments made on or before the due date"): DesignSystem.Color.green,
            String(localized: "Late", comment: "Legend label for payments made after the due date"): DesignSystem.Color.red
        ])
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: 180)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("\(intValue)")
                            .font(.caption2)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Text("No payments recorded yet", comment: "Empty state for payment timing chart when no payment history exists")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, DesignSystem.Spacing.large)
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        guard let percentage = data.onTimePercentage else {
            return String(
                localized: "On-time payments over the last 6 months. No payments recorded yet.",
                comment: "VoiceOver description for empty payment timing chart"
            )
        }

        let monthsSummary = data.points
            .map { "\($0.monthLabel): \($0.onTimeCount) on time, \($0.lateCount) late" }
            .joined(separator: ", ")

        return String(
            localized: "On-time payments over the last 6 months: \(Int(percentage.rounded())) percent. \(monthsSummary).",
            comment: "VoiceOver description for payment timing chart"
        )
    }
}

#Preview {
    VStack {
        PaymentTimingChart(data: PaymentTimingData(
            points: [
                PaymentTimingMonthPoint(month: Date(), monthLabel: "Feb", onTimeCount: 10, lateCount: 1),
                PaymentTimingMonthPoint(month: Date(), monthLabel: "Mar", onTimeCount: 12, lateCount: 0),
                PaymentTimingMonthPoint(month: Date(), monthLabel: "Apr", onTimeCount: 9, lateCount: 3),
                PaymentTimingMonthPoint(month: Date(), monthLabel: "May", onTimeCount: 11, lateCount: 2),
                PaymentTimingMonthPoint(month: Date(), monthLabel: "Jun", onTimeCount: 12, lateCount: 0),
                PaymentTimingMonthPoint(month: Date(), monthLabel: "Jul", onTimeCount: 6, lateCount: 1)
            ],
            onTimePercentage: 89.5,
            averageDaysLate: -1.2
        ))

        PaymentTimingChart(data: PaymentTimingData(
            points: [],
            onTimePercentage: nil,
            averageDaysLate: nil
        ))
    }
    .padding()
}
