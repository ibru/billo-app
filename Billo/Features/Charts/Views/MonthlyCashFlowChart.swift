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

            legend

            netSummary
        }
        .chartCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let incomeFormatted = data.income.formatted(.currency(code: currencyCode))
        let paidFormatted = data.billsPaid.formatted(.currency(code: currencyCode))
        let outstandingFormatted = data.billsOutstanding.formatted(.currency(code: currencyCode))
        let netFormatted = data.net.formatted(.currency(code: currencyCode))
        return String(
            localized: "Monthly cash flow for \(data.monthLabel). Income: \(incomeFormatted). Bills paid: \(paidFormatted). Bills still due: \(outstandingFormatted). Net: \(netFormatted).",
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
            .foregroundStyle(DesignSystem.Color.greenIncome)

            // Same x category stacks automatically: what actually left the
            // account (paid) below, what's still owed (outstanding) on top.
            BarMark(
                x: .value("Type", String(localized: "Bills")),
                y: .value("Amount", data.billsPaid)
            )
            .foregroundStyle(DesignSystem.Color.green)

            BarMark(
                x: .value("Type", String(localized: "Bills")),
                y: .value("Amount", data.billsOutstanding)
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

    @ViewBuilder
    private var legend: some View {
        if data.billsPaid > 0 || data.billsOutstanding > 0 {
            HStack(spacing: DesignSystem.Spacing.medium) {
                if data.billsPaid > 0 {
                    legendItem(
                        color: DesignSystem.Color.green,
                        label: Text("Paid", comment: "Cash flow legend label for bills already paid"),
                        amount: data.billsPaid
                    )
                }

                if data.billsOutstanding > 0 {
                    legendItem(
                        color: DesignSystem.Color.red,
                        label: Text("Still due", comment: "Cash flow legend label for bills not yet paid"),
                        amount: data.billsOutstanding
                    )
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func legendItem(color: Color, label: Text, amount: Decimal) -> some View {
        HStack(spacing: DesignSystem.Spacing.extraSmall) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            label
                .font(.caption)

            Text(amount, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var netSummary: some View {
        HStack {
            Label(String(localized: "Net", comment: "Label for net cash flow (income minus bills)"), systemImage: "equal.circle")
                .foregroundStyle(.secondary)

            Spacer()

            Text(data.net, format: .currency(code: currencyCode))
                .foregroundStyle(data.net >= 0
                    ? DesignSystem.Color.greenIncome
                    : DesignSystem.Color.red)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    VStack {
        MonthlyCashFlowChart(data: MonthlyCashFlowData(
            monthLabel: "January 2026",
            income: 4500,
            billsPaid: 2100,
            billsOutstanding: 1100
        ))

        MonthlyCashFlowChart(data: MonthlyCashFlowData(
            monthLabel: "February 2026",
            income: 4500,
            billsPaid: 0,
            billsOutstanding: 3200
        ))
    }
    .padding()
}
