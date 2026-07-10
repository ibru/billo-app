//  Created by Jiri Urbasek on 12/25/25.

import SwiftUI
import SwiftData

struct ChartsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsModel.self) private var appSettingsModel

    @State private var chartsModel: ChartsModel?

    private var currencyCode: String {
        appSettingsModel.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        content
            .navigationTitle("Charts")
            .platformInlineNavigationTitle()
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
    }

    @ViewBuilder
    private var content: some View {
        if let chartsModel, let state = chartsModel.state {
            if state.hasData {
                chartsScrollView(model: chartsModel, state: state)
            } else {
                emptyState
            }
        } else {
            ProgressView()
        }
    }

    private func chartsScrollView(model: ChartsModel, state: ChartsState) -> some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.medium) {
                MonthSwitcherHeader(model: model)

                MonthlyCashFlowChart(
                    data: state.cashFlow,
                    currencyCode: currencyCode
                )

                CategoryBreakdownChart(
                    data: state.categoryBreakdown,
                    currencyCode: currencyCode
                )

                PaymentTimingChart(
                    data: state.paymentTiming
                )

                MonthlyTrendChart(
                    data: state.monthlyTrend,
                    currencyCode: currencyCode
                )

                CategoryTrendChart(
                    data: state.categoryTrend,
                    currencyCode: currencyCode
                )
            }
            .padding()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            String(localized: "No Data Yet", comment: "Title for empty charts state"),
            systemImage: "chart.bar.xaxis",
            description: Text("Add some bills or income to see your spending insights", comment: "Description for empty charts state")
        )
    }

    @MainActor
    private func loadData() async {
        if chartsModel == nil {
            chartsModel = ChartsModel(modelContext: modelContext)
        }
        chartsModel?.refresh()
    }
}

/// Shared month pager for the month-scoped charts (cash flow and category
/// breakdown). The trend charts below it always stay anchored to today.
private struct MonthSwitcherHeader: View {
    let model: ChartsModel

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.extraSmall) {
            HStack {
                Button {
                    withAnimation {
                        model.stepMonth(by: -1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(Text("Previous month", comment: "Accessibility label for the charts month switcher back button"))
                .accessibilityIdentifier("charts_previous_month")

                Spacer()

                Text(model.selectedMonthLabel)
                    .font(.headline)
                    .accessibilityIdentifier("charts_selected_month")

                Spacer()

                Button {
                    withAnimation {
                        model.stepMonth(by: 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(Text("Next month", comment: "Accessibility label for the charts month switcher forward button"))
                .accessibilityIdentifier("charts_next_month")
            }

            if !model.isViewingCurrentMonth {
                Button {
                    withAnimation {
                        model.resetToCurrentMonth()
                    }
                } label: {
                    Text("Back to current month", comment: "Button returning the charts month switcher to today's month")
                        .font(.caption)
                }
                .accessibilityIdentifier("charts_reset_month")
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChartsView()
    }
}
