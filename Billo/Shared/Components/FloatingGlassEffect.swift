//  Created by Jiri Urbasek on 12/25/25.

import SwiftUI

extension View {
    func billoFloatingGlassEffect<S: Shape>(
        _ glass: Glass = .regular,
        in shape: S
    ) -> some View {
        background {
            GlassEffectContainer {
                Color.clear
            }
            .glassEffect(glass.interactive(true), in: shape)
            .allowsHitTesting(false)
        }
    }

    func billoFloatingGlassEffect(_ glass: Glass = .regular) -> some View {
        billoFloatingGlassEffect(glass, in: Capsule())
    }
}
