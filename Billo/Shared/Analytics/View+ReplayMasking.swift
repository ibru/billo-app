//  Created by Jiri Urbasek on 07/10/26.

import SwiftUI
import PostHog

/// Single source of truth for "will this process ever set up PostHog?".
/// Decided once, before any UI exists, from process-constant inputs — so it
/// is safe to gate view-level replay masking on it: session replay can never
/// start in a process where PostHog is never set up.
enum AnalyticsEnvironment {
    static let isAnalyticsEnabled: Bool = {
        #if SCREENSHOTS
        return false
        #else
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return false }
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return false }

        #if DEBUG
        return ProcessInfo.processInfo.environment["BILLO_ENABLE_ANALYTICS"] == "1"
        #else
        return true
        #endif
        #endif
    }()
}

extension View {
    /// Masks this view in PostHog session replays.
    ///
    /// Global text masking is intentionally OFF (`maskAllTextInputs = false`)
    /// so replays show static UI. Sensitive financial data is therefore
    /// opt-in masked: apply this to any view rendering a currency amount,
    /// user-entered name or note, account identifier, provider URL, payment
    /// confirmation number, or custom category name.
    /// Any NEW money or name surface must add this, or it leaks into replays.
    ///
    /// `postHogMask()` injects hidden UIKit tag views and re-runs view-
    /// hierarchy traversals on every layout pass — a real scrolling cost when
    /// applied per row — so it is skipped entirely in processes that never
    /// set up PostHog (tests, previews, screenshots, DEBUG runs without
    /// `BILLO_ENABLE_ANALYTICS=1`). Replay cannot record there, so nothing
    /// can leak.
    @ViewBuilder
    func replayMaskSensitive() -> some View {
        if AnalyticsEnvironment.isAnalyticsEnabled {
            postHogMask()
        } else {
            self
        }
    }
}
