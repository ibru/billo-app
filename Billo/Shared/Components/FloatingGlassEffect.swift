//  Created by Jiri Urbasek on 12/25/25.

import SwiftUI

extension View {
    @ViewBuilder
    func billoFloatingGlassEffect<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, macCatalyst 26.0, *) {
            background {
                GlassEffectContainer {
                    Color.clear
                }
                .glassEffect(.regular.interactive(true), in: shape)
                .allowsHitTesting(false)
            }
        } else {
            background(.ultraThinMaterial, in: shape)
        }
    }

    func billoFloatingGlassEffect() -> some View {
        billoFloatingGlassEffect(in: Capsule())
    }
}
