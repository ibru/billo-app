//  Created by Jiri Urbasek on 7/24/26.

import SwiftUI

/// The app-level `@Observable` models, captured from the presenting view's
/// environment so presented sheet/popover content can re-inject them.
///
/// Mac Catalyst (macOS 26, verified on 26.3.1) does not propagate
/// `@Observable` environment values into presented sheet/popover content the
/// way iOS does — the first `@Environment(SomeModel.self)` read inside the
/// presented tree traps with "No Observable object of type … found"
/// (reproduced: MarkPaidSheet's partial-payment gate presenting the paywall).
/// Until the platform bug is fixed, EVERY sheet/popover content root must
/// re-inject the models explicitly:
///
///     private var appModels = AppEnvironmentModels()
///     ...
///     .sheet(isPresented: $showingEdit) {
///         BillEditView(mode: .adding)
///             .appEnvironment(appModels)
///     }
///
/// Screen-scoped models that aren't app-wide (`BillModel`,
/// `NotificationSettingsModel`) stay out of the bundle — call sites keep
/// injecting those individually. Views pushed inside a presented
/// `NavigationStack` need nothing extra; only the presentation boundary
/// loses the environment.
struct AppEnvironmentModels: DynamicProperty {
    @Environment(BillsModel.self) fileprivate var billsModel
    @Environment(AppSettingsModel.self) fileprivate var appSettingsModel
    @Environment(StoreKitManager.self) fileprivate var storeKit
    @Environment(AnalyticsModel.self) fileprivate var analytics
    @Environment(ReviewPromptModel.self) fileprivate var reviewPrompts
}

extension View {
    /// Re-injects the app-level models into presented content — required on
    /// every sheet/popover content root because Mac Catalyst drops
    /// `@Observable` environment values at the presentation boundary
    /// (see `AppEnvironmentModels`).
    func appEnvironment(_ models: AppEnvironmentModels) -> some View {
        self
            .environment(models.billsModel)
            .environment(models.appSettingsModel)
            .environment(models.storeKit)
            .environment(models.analytics)
            .environment(models.reviewPrompts)
    }
}
