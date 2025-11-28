//
//  BilloApp.swift
//  Billo
//
//  Created by Jiri Urbasek on 11/25/25.
//

import SwiftUI
import SwiftData

@main
struct BilloApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Bill.self,
            Payment.self,
            RecurrenceRule.self,
            Income.self,
            CustomCategory.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var billsModel: BillsModel?
    @State private var paymentHistoryModel: PaymentHistoryModel?

    var body: some Scene {
        WindowGroup {
            if let billsModel, let paymentHistoryModel {
                BillsListView()
                    .environment(billsModel)
                    .environment(paymentHistoryModel)
            } else {
                ProgressView()
                    .task {
                        let context = sharedModelContainer.mainContext
                        let historyModel = PaymentHistoryModel(modelContext: context)
                        let bills = BillsModel(
                            modelContext: context,
                            paymentHistoryRefresher: historyModel
                        )

                        paymentHistoryModel = historyModel
                        billsModel = bills
                    }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
