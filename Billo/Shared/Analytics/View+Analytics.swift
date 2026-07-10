//  Created by Jiri Urbasek on 07/10/26.

import SwiftUI

extension View {
    /// Tracks a screen view on every appearance — including re-appearance
    /// after popping back from a pushed screen. Deliberate: each reappearance
    /// counts as a screen view (same semantics as Savemo).
    func analyticsScreen(_ screen: AnalyticsScreen, properties: [String: Any] = [:]) -> some View {
        modifier(AnalyticsScreenModifier(screen: screen, properties: properties))
    }
}

private struct AnalyticsScreenModifier: ViewModifier {
    @Environment(AnalyticsModel.self) private var analytics

    let screen: AnalyticsScreen
    let properties: [String: Any]

    func body(content: Content) -> some View {
        content.onAppear {
            analytics.screen(screen, properties: properties)
        }
    }
}
