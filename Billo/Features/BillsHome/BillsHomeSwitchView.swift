//  Created by Jiri Urbasek on 12/05/25.

import SwiftUI
import SwiftData
import UIKit

struct BillsHomeSwitchView: View {
    @AppStorage("billsDefaultView") private var viewModeRawValue: String = BillsHomeViewMode.list.rawValue

    @Environment(BillsModel.self) private var billsModel
    @Environment(NotificationCoordinator.self) private var notificationCoordinator
    @Environment(NotificationPreferencesStore.self) private var preferencesStore
    @Environment(AnalyticsModel.self) private var analytics
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var showingAddBill = false
    @State private var showingSettings = false
    @State private var calendarIsAtCurrentMonth = true
    @State private var calendarScrollToTodayToken = 0
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var selection: HomeDetailDestination?
    @State private var detailPath: [HomeDetailDestination] = []

    private var usesStackNavigation: Bool {
        horizontalSizeClass == .compact
    }

    private var nextViewMode: BillsHomeViewMode {
        switch viewModeBinding.wrappedValue {
        case .list: .calendar
        case .calendar: .list
        }
    }

    private var viewModeBinding: Binding<BillsHomeViewMode> {
        Binding {
            BillsHomeViewMode(rawValue: viewModeRawValue) ?? .list
        } set: { newValue in
            viewModeRawValue = newValue.rawValue
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            if usesStackNavigation == false {
                masterColumnContent
                    .navigationSplitViewColumnWidth(min: 380, ideal: 450, max: 520)
            } else {
                masterColumnContent
            }
        } detail: {
            NavigationStack(path: $detailPath) {
                if let selection {
                    destinationView(for: selection)
                } else {
                    ContentUnavailableView(
                        "Select a bill",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Choose an item from the list or calendar")
                    )
                }
            }
            .navigationDestination(for: HomeDetailDestination.self) { destination in
                destinationView(for: destination)
            }
        }
        .onChange(of: selection) { _, _ in
            detailPath.removeAll()
        }
        .sheet(isPresented: $showingAddBill) {
            BillEditView(mode: .adding)
                .environment(billsModel)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView(
                    notificationSettingsModel: NotificationSettingsModel(
                        preferences: preferencesStore,
                        coordinator: notificationCoordinator,
                        openSettingsHandler: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        },
                        refreshScheduler: NotificationRefreshDebouncer(
                            refresh: { [weak billsModel, weak notificationCoordinator] in
                                guard let billsModel, let notificationCoordinator else { return }
                                await AppNotificationRefresher().refreshAndReschedule(
                                    billsModel: billsModel,
                                    coordinator: notificationCoordinator,
                                    refreshBills: false
                                )
                            }
                        ),
                        analyticsCapture: { [weak analytics] event in
                            analytics?.capture(event)
                        }
                    )
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingSettings = false
                        }
                    }
                }
            }
        }
    }

    private var moreMenu: some View {
        Menu {
            Button {
                showingSettings = true
            } label: {
                Label("Settings", systemImage: "gear")
            }

            if horizontalSizeClass == .compact {
                NavigationLink(value: HomeDetailDestination.charts) {
                    Label("Charts", systemImage: "chart.bar")
                }
            } else {
                Button {
                    openSelection(.charts)
                } label: {
                    Label("Charts", systemImage: "chart.bar")
                }
            }

            if horizontalSizeClass == .compact {
                NavigationLink(value: HomeDetailDestination.dataExport) {
                    Label("Data Export", systemImage: "square.and.arrow.up")
                }
            } else {
                Button {
                    openSelection(.dataExport)
                } label: {
                    Label("Data Export", systemImage: "square.and.arrow.up")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel(Text("More"))
    }

    @ViewBuilder
    private var masterColumnContent: some View {
        if horizontalSizeClass == .compact {
            masterColumnBase
                .navigationDestination(for: HomeDetailDestination.self) { destination in
                    destinationView(for: destination)
                }
        } else {
            masterColumnBase
        }
    }

    private var masterColumnBase: some View {
        masterContent
            .platformInlineNavigationTitle()
            .toolbarBackground(
                viewModeBinding.wrappedValue == .calendar ? Color.white : Color.clear,
                for: .navigationBar
            )
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { moreMenu }

                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        let target = nextViewMode
                        withAnimation {
                            viewModeBinding.wrappedValue = target
                        }
                        analytics.capture(.viewModeChanged(to: target.rawValue))
                    } label: {
                        Image(systemName: nextViewMode.iconName)
                    }
                    .accessibilityLabel(
                        viewModeBinding.wrappedValue == .list
                            ? Text("Switch to Calendar")
                            : Text("Switch to List")
                    )

                    Button {
                        showingAddBill = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if usesStackNavigation || viewModeBinding.wrappedValue == .calendar {
                    HomeFloatingBottomBarView(
                        showToday: viewModeBinding.wrappedValue == .calendar && !calendarIsAtCurrentMonth,
                        usesStackNavigation: usesStackNavigation,
                        onToday: { calendarScrollToTodayToken += 1 },
                        onOpen: openSelection
                    )
                } else {
                    EmptyView()
                }
            }
    }

    @ViewBuilder
    private var masterContent: some View {
        switch viewModeBinding.wrappedValue {
        case .list:
            BillsListView(
                usesStackNavigation: usesStackNavigation,
                onAddBill: { showingAddBill = true },
                onOpen: openSelection
            )
                .navigationTitle("Bills")
        case .calendar:
            BillsCalendarView(
                usesStackNavigation: usesStackNavigation,
                onAddBill: { showingAddBill = true },
                onOpen: openSelection,
                isAtCurrentMonth: $calendarIsAtCurrentMonth,
                scrollToTodayToken: $calendarScrollToTodayToken
            )
        }
    }

    private func openSelection(_ destination: HomeDetailDestination) {
        selection = destination
    }

    @ViewBuilder
    private func destinationView(for destination: HomeDetailDestination) -> some View {
        switch destination {
        case .bill(let billID):
            if let bill = modelContext.model(for: billID) as? Bill {
                BillDetailView(bill: bill)
                    .environment(BillModel(bill: bill, modelContext: modelContext))
            } else {
                ContentUnavailableView(
                    "Bill Not Found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This bill may have been deleted")
                )
            }

        case .occurrence(let occurrenceID):
            if let occurrence = modelContext.model(for: occurrenceID) as? IssuedOccurrence {
                OccurrenceDetailView(occurrence: occurrence)
            } else {
                ContentUnavailableView(
                    "Occurrence Not Found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This occurrence may have been deleted")
                )
            }

        case .paymentHistory:
            PaymentHistoryView()

        case .payment(let paymentID):
            if let payment = modelContext.model(for: paymentID) as? PaymentEntry {
                PaymentDetailView(payment: payment)
            } else {
                ContentUnavailableView(
                    "Payment Not Found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This payment may have been deleted")
                )
            }

        case .incomeList:
            IncomeListView()

        case .income(let incomeID):
            if let income = modelContext.model(for: incomeID) as? Income {
                IncomeDetailView(income: income)
            } else {
                ContentUnavailableView(
                    "Income Not Found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This income may have been deleted")
                )
            }

        case .incomeOccurrence(let occurrenceID):
            if let occurrence = modelContext.model(for: occurrenceID) as? IncomeOccurrence {
                IncomeOccurrenceDetailView(occurrence: occurrence)
            } else {
                ContentUnavailableView(
                    "Income Occurrence Not Found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This occurrence may have been deleted")
                )
            }

        case .charts:
            ChartsView()

        case .dataExport:
            DataExportView()
        }
    }
}

private struct HomeFloatingBottomBarView: View {
    let showToday: Bool
    let usesStackNavigation: Bool
    let onToday: () -> Void
    let onOpen: (HomeDetailDestination) -> Void

	    var body: some View {
	        HStack(alignment: .center) {
	            if showToday {
                FloatingPillButton(
                    verticalPadding: 4,
                    horizontalPadding: 4,
                    action: onToday
	                ) {
	                    Text("Today")
	                        .font(.headline)
	                        .frame(height: 44)
	                        .padding(.horizontal, DesignSystem.Spacing.medium)
	                }
	                .accessibilityLabel(Text("Today"))
	            }

            Spacer(minLength: DesignSystem.Spacing.small)

            HomeFloatingQuickActionsView(
                usesStackNavigation: usesStackNavigation,
                onOpen: onOpen
            )
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.top, DesignSystem.Spacing.extraSmall)
    }
}

private struct HomeFloatingQuickActionsView: View {
    let usesStackNavigation: Bool
    let onOpen: (HomeDetailDestination) -> Void

    @ViewBuilder
    private func quickAction(
        destination: HomeDetailDestination,
        systemImage: String
    ) -> some View {
        if usesStackNavigation {
            NavigationLink(value: destination) {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
            }
        } else {
            Button {
                onOpen(destination)
            } label: {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }

	    var body: some View {
	        FloatingPill {
	            HStack(spacing: 0) {
                quickAction(
                    destination: .paymentHistory,
                    systemImage: "clock.arrow.circlepath"
                )
                .buttonStyle(.plain)
	                .frame(width: 52, height: 44)
	                .contentShape(Rectangle())
	                .accessibilityLabel(Text("Payment History"))

                Divider()
                    .frame(height: 22)

                quickAction(
                    destination: .incomeList,
                    systemImage: "wallet.bifold"
                )
                .buttonStyle(.plain)
	                .frame(width: 52, height: 44)
	                .contentShape(Rectangle())
	                .accessibilityLabel(Text("Income"))
	            }
	            .font(.headline)
	            .foregroundStyle(DesignSystem.Color.greenIncome)
	        }
	    }
	}

#Preview("Bills Home (Sample Data)") {
    let preview = BilloPreviewContainer.withSampleData()
    return BillsHomeSwitchView()
        .billoPreviewEnvironment(preview)
}

#Preview("Bills Home (Empty)") {
    let preview = BilloPreviewContainer.empty()
    return BillsHomeSwitchView()
        .billoPreviewEnvironment(preview)
}
