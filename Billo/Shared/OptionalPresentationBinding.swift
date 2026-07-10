//  Created by Jiri Urbasek on 07/09/26.

import SwiftUI

extension Binding where Value == Bool {
    /// Bridges optional "presented item" state to `isPresented:` APIs:
    /// true while `source` is non-nil; setting false (dismissal) clears it.
    /// Use instead of hand-rolling `Binding(get:set:)` at each alert/sheet.
    init<Wrapped>(isPresent source: Binding<Wrapped?>) {
        self.init(
            get: { source.wrappedValue != nil },
            set: { if !$0 { source.wrappedValue = nil } }
        )
    }
}
