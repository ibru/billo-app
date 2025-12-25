//  Created by Jiri Urbasek on 12/05/25.

import SwiftUI

enum AppDestination: Hashable {
    case paymentHistory
    case incomeList
    case charts
    case dataExport
}

struct BillsHomeSwitchView: View {
    @AppStorage("billsDefaultView") private var viewModeRawValue: String = BillsHomeViewMode.list.rawValue

    @Environment(BillsModel.self) private var billsModel
    @Environment(NotificationCoordinator.self) private var notificationCoordinator
    @Environment(NotificationPreferencesStore.self) private var preferencesStore
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddBill = false
    @State private var showingSettings = false
    @State private var navigationPath = NavigationPath()
    @State private var calendarIsAtCurrentMonth = true
    @State private var calendarScrollToTodayToken = 0

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
        NavigationStack(path: $navigationPath) {
            Group {
                switch viewModeBinding.wrappedValue {
                case .list:
                    BillsListView()
                        .navigationTitle("Bills")
                case .calendar:
                    BillsCalendarView(
                        onAddBill: { showingAddBill = true },
                        isAtCurrentMonth: $calendarIsAtCurrentMonth,
                        scrollToTodayToken: $calendarScrollToTodayToken
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Bill.self) { bill in
                BillDetailView(bill: bill)
                    .environment(BillModel(bill: bill, modelContext: modelContext))
            }
            .navigationDestination(for: Payment.self) { payment in
                PaymentDetailView(payment: payment)
            }
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .paymentHistory:
                    PaymentHistoryView()
                case .incomeList:
                    IncomeListView()
                case .charts:
                    ChartsView()
                case .dataExport:
                    DataExportView()
                }
            }
            .navigationDestination(for: Income.self) { income in
                IncomeDetailView(income: income)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            showingSettings = true
                        } label: {
                            Label(String(localized: "Settings"), systemImage: "gear")
                        }

                        Button {
                            navigationPath.append(AppDestination.charts)
                        } label: {
                            Label(String(localized: "Charts"), systemImage: "chart.bar")
                        }

                        Button {
                            navigationPath.append(AppDestination.dataExport)
                        } label: {
                            Label(String(localized: "Data Export"), systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel(String(localized: "More"))
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        withAnimation {
                            viewModeBinding.wrappedValue = nextViewMode
                        }
                    } label: {
                        Image(systemName: nextViewMode.iconName)
                    }
                    .accessibilityLabel(
                        viewModeBinding.wrappedValue == .list
                            ? String(localized: "Switch to Calendar")
                            : String(localized: "Switch to List")
                    )

                    Button {
                        showingAddBill = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HomeFloatingBottomBarView(
                    showToday: viewModeBinding.wrappedValue == .calendar && !calendarIsAtCurrentMonth,
                    onToday: { calendarScrollToTodayToken += 1 },
                    onPaymentHistory: { navigationPath.append(AppDestination.paymentHistory) },
                    onIncome: { navigationPath.append(AppDestination.incomeList) }
                )
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
#if os(iOS)
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
#endif
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
    }
}

private struct HomeFloatingBottomBarView: View {
    let showToday: Bool
    let onToday: () -> Void
    let onPaymentHistory: () -> Void
    let onIncome: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            if showToday {
                FloatingPillButton(
                    verticalPadding: 4,
                    horizontalPadding: 4,
                    action: onToday
                ) {
                    Text(String(localized: "Today"))
                        .font(.headline)
                        .frame(height: 44)
                        .padding(.horizontal, DesignSystem.Spacing.medium)
                }
                .accessibilityLabel(String(localized: "Today"))
            }

            Spacer(minLength: DesignSystem.Spacing.small)

            HomeFloatingQuickActionsView(
                onPaymentHistory: onPaymentHistory,
                onIncome: onIncome
            )
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.top, DesignSystem.Spacing.extraSmall)
    }
}

private struct HomeFloatingQuickActionsView: View {
    let onPaymentHistory: () -> Void
    let onIncome: () -> Void

    var body: some View {
        FloatingPill {
            HStack(spacing: 0) {
                Button(action: onPaymentHistory) {
                    Image(systemName: "clock.arrow.circlepath")
                        .symbolRenderingMode(.hierarchical)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(String(localized: "Payment History"))

                Divider()
                    .frame(height: 22)

                Button(action: onIncome) {
                    Image(systemName: "banknote")
                        .symbolRenderingMode(.hierarchical)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(String(localized: "Income"))
            }
            .font(.headline)
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
