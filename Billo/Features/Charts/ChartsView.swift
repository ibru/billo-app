//  Created by Jiri Urbasek on 12/25/25.

import SwiftUI
import SwiftData

struct ChartsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsModel.self) private var appSettingsModel
    @Environment(StoreKitManager.self) private var storeKit
    @Environment(AnalyticsModel.self) private var analytics

    @State private var chartsModel: ChartsModel?
    @State private var paywallContext: PaywallContext?

    private var currencyCode: String {
        appSettingsModel.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        content
            .replayMaskSensitive()
            .navigationTitle("Charts")
            .platformInlineNavigationTitle()
            .analyticsScreen(.charts)
            .paywallSheet(context: $paywallContext)
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
                if FreeTierLimits.canViewCharts(isPro: storeKit.isPro) {
                    chartsScrollView(model: chartsModel, state: state)
                } else {
                    // Real charts advertise the feature underneath; blur keeps
                    // the numbers unreadable and hit-testing is off so
                    // scrolling can't reveal content past the viewport.
                    chartsScrollView(model: chartsModel, state: state)
                        .blur(radius: 12)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .overlay {
                            chartsUpgradeOverlay
                        }
                }
            } else {
                // Free users with no data see the normal empty state — a
                // blurred empty placeholder would look broken and gate nothing.
                emptyState
            }
        } else {
            ProgressView()
        }
    }

    private var chartsUpgradeOverlay: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            Text("Unlock spending insights with Billo Pro", comment: "Charts upgrade overlay message for free users")
                .font(.headline)
                .multilineTextAlignment(.center)

            Button {
                analytics.capture(.proGateHit(feature: PaywallContext.charts.analyticsKey))
                paywallContext = .charts
            } label: {
                Text("Upgrade to Pro", comment: "Charts upgrade overlay button")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("charts_upgrade_button")
        }
        .padding(DesignSystem.Spacing.large)
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
    .billoPreviewEnvironment(BilloPreviewContainer.withSampleData())
}

#Preview("Free tier (blurred)") {
    NavigationStack {
        ChartsView()
    }
    .billoPreviewEnvironment(BilloPreviewContainer.withSampleData(), isPro: false)
}
