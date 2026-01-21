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
        if let state = chartsModel?.state {
            if state.hasData {
                chartsScrollView(state: state)
            } else {
                emptyState
            }
        } else {
            ProgressView()
        }
    }

    private func chartsScrollView(state: ChartsState) -> some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.medium) {
                MonthlyCashFlowChart(
                    data: state.cashFlow,
                    currencyCode: currencyCode
                )

                CategoryBreakdownChart(
                    data: state.categoryBreakdown,
                    currencyCode: currencyCode
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

#Preview {
    NavigationStack {
        ChartsView()
    }
}
