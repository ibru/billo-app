//  Created by Jiri Urbasek on 01/21/26.

import SwiftUI
import Charts

struct MonthlyCashFlowChart: View {
    let data: MonthlyCashFlowData
    var currencyCode: String = Locale.current.currency?.identifier ?? "USD"

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            header

            chart

            netSummary
        }
        .chartCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let incomeFormatted = data.income.formatted(.currency(code: currencyCode))
        let billsFormatted = data.bills.formatted(.currency(code: currencyCode))
        let netFormatted = data.net.formatted(.currency(code: currencyCode))
        return String(
            localized: "Monthly cash flow for \(data.monthLabel). Income: \(incomeFormatted). Bills: \(billsFormatted). Net: \(netFormatted).",
            comment: "VoiceOver description for monthly cash flow chart"
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
            Text("Monthly Cash Flow", comment: "Chart title for monthly income vs bills comparison")
                .font(.headline)

            Text(data.monthLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var chart: some View {
        Chart {
            BarMark(
                x: .value("Type", String(localized: "Income")),
                y: .value("Amount", data.income)
            )
            .foregroundStyle(DesignSystem.Color.green)

            BarMark(
                x: .value("Type", String(localized: "Bills")),
                y: .value("Amount", data.bills)
            )
            .foregroundStyle(DesignSystem.Color.red)
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
    }

    private var netSummary: some View {
        HStack {
            Label(String(localized: "Net", comment: "Label for net cash flow (income minus bills)"), systemImage: "equal.circle")
                .foregroundStyle(.secondary)

            Spacer()

            Text(data.net, format: .currency(code: currencyCode))
                .foregroundStyle(data.net >= 0
                    ? DesignSystem.Color.green
                    : DesignSystem.Color.red)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    MonthlyCashFlowChart(data: MonthlyCashFlowData(
        monthLabel: "January 2026",
        income: 4500,
        bills: 3200
    ))
    .padding()
}
