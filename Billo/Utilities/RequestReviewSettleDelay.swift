//  Created by Jiri Urbasek on 7/16/26.

import StoreKit
import SwiftUI

// Explicit @MainActor so the contract doesn't depend on the target's
// default-isolation build setting.
@MainActor
extension RequestReviewAction {
    /// Presents the system rating dialog after letting the current transition
    /// (sheet dismissal, paid-row animation) settle. Aborts when the
    /// surrounding task is cancelled: skipping one ask is harmless — iOS
    /// ignores most requests anyway — while firing with zero delay
    /// mid-navigation is exactly what the delay exists to prevent.
    func requestAfterSettleDelay() async {
        guard (try? await Task.sleep(for: .seconds(1))) != nil else { return }
        self()
    }
}
