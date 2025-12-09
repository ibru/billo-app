//  Created by Jiri Urbasek on 12/05/25.

import SwiftUI

enum AppDestination: Hashable {
    case paymentHistory
}

struct BillsHomeSwitchView: View {
    @AppStorage("billsDefaultView") private var viewModeRawValue: String = BillsHomeViewMode.list.rawValue

    @Environment(BillsModel.self) private var billsModel
    @Environment(NotificationCoordinator.self) private var notificationCoordinator
    @Environment(NotificationPreferencesStore.self) private var preferencesStore
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddBill = false
    @State private var showingSettings = false

    private var viewModeBinding: Binding<BillsHomeViewMode> {
        Binding {
            BillsHomeViewMode(rawValue: viewModeRawValue) ?? .list
        } set: { newValue in
            viewModeRawValue = newValue.rawValue
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModeBinding.wrappedValue {
                case .list:
                    BillsListView()
                case .calendar:
                    BillsCalendarView(onAddBill: { showingAddBill = true })
                }
            }
            .navigationTitle("Bills")
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
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddBill = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .toolbarTitleMenu {
                Picker("Default view", selection: viewModeBinding) {
                    ForEach(BillsHomeViewMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.iconName).tag(mode)
                    }
                }
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
