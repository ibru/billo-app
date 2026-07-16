//
//  View+PlatformNavigation.swift
//  Billo
//
//  Created by Jiri Urbasek on 12/30/25.
//

import SwiftUI

extension View {
    @ViewBuilder
    func platformInlineNavigationTitle() -> some View {
        navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    func platformListSectionSpacing(_ spacing: CGFloat) -> some View {
        listSectionSpacing(spacing)
    }

    @ViewBuilder
    func platformDecimalKeyboard() -> some View {
        keyboardType(.decimalPad)
    }

    @ViewBuilder
    func platformURLKeyboard() -> some View {
        keyboardType(.URL)
    }

    @ViewBuilder
    func platformNeverAutocapitalization() -> some View {
        textInputAutocapitalization(.never)
    }

    /// Presentation detents are iOS/iPadOS-only — they add nothing on the
    /// Mac, where sheets are fixed-size form sheets. Apply them on iOS only
    /// so the Catalyst presentation controller never sees an unsupported
    /// configuration.
    @ViewBuilder
    func platformPresentationDetents(_ detents: Set<PresentationDetent>) -> some View {
        #if targetEnvironment(macCatalyst)
        self
        #else
        presentationDetents(detents)
        #endif
    }
}
