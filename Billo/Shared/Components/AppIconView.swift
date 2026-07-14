//  Created by Jiri Urbasek on 7/14/26.

import SwiftUI

/// Renders the app icon artwork at an arbitrary size with the iOS icon
/// rounded-square mask, for places that *simulate* the real icon (mock
/// notification banners, paywall hero). Uses the `AppIconPreview` image set —
/// the actual `AppIcon` asset can't be referenced as a SwiftUI `Image`.
struct AppIconView: View {
    let size: CGFloat

    /// Apple's home-screen icon corner radius is ≈ 22.37% of the icon size.
    private var cornerRadius: CGFloat { size * 0.2237 }

    var body: some View {
        Image("AppIconPreview")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 20) {
        AppIconView(size: 40)
        AppIconView(size: 96)
    }
    .padding()
}
