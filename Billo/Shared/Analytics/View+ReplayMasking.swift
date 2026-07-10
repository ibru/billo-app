//  Created by Jiri Urbasek on 07/10/26.

import SwiftUI
import PostHog

extension View {
    /// Masks this view in PostHog session replays.
    ///
    /// Global text masking is intentionally OFF (`maskAllTextInputs = false`)
    /// so replays show static UI. Sensitive financial data is therefore
    /// opt-in masked: apply this to any view rendering a currency amount,
    /// user-entered name or note, account identifier, provider URL, payment
    /// confirmation number, or custom category name.
    /// Any NEW money or name surface must add this, or it leaks into replays.
    func replayMaskSensitive() -> some View {
        postHogMask()
    }
}
