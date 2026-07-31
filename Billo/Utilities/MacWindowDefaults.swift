//  Created by Jiri Urbasek on 07/30/26.

import SwiftUI

/// Default window size for the Mac (Catalyst) app.
///
/// SwiftUI's `.defaultSize(width:height:)` is unavailable on Mac Catalyst, so
/// the default is requested through UIKit instead — and only on the very
/// first launch. Catalyst persists and restores the window frame on its own,
/// so once the user resizes the window their choice must win; re-applying the
/// default on every launch would fight it.
enum MacWindowDefaults {
    /// Portrait-ish split view: sidebar plus a comfortable detail pane,
    /// in AppKit points (`systemFrame` space). Also the size the App Store
    /// screenshot pipeline pins (`scripts/capture-appstore-mac-shots.sh`) —
    /// keep the two in sync so the store captures show the real default.
    static let defaultSize = CGSize(width: 928, height: 792)

    private static let appliedDefaultsKey = "didApplyDefaultMacWindowSize"

    @MainActor
    static func applyIfFirstLaunch() {
#if targetEnvironment(macCatalyst)
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: appliedDefaultsKey) else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }

        defaults.set(true, forKey: appliedDefaultsKey)

        var frame = scene.effectiveGeometry.systemFrame
        frame.size = defaultSize
        scene.requestGeometryUpdate(.Mac(systemFrame: frame))
#endif
    }
}
