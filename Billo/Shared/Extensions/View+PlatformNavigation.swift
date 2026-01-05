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
}
