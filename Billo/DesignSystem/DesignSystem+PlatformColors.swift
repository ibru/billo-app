//
//  DesignSystem+PlatformColors.swift
//  Billo
//
//  Created by Jiri Urbasek on 12/30/25.
//

import SwiftUI

import UIKit

extension DesignSystem.Color {
    static var background: SwiftUI.Color {
        SwiftUI.Color(uiColor: .systemBackground)
    }

    static var groupedBackground: SwiftUI.Color {
        SwiftUI.Color(uiColor: .systemGroupedBackground)
    }

    static var separator: SwiftUI.Color {
        SwiftUI.Color(uiColor: .separator)
    }

    static var tertiaryLabel: SwiftUI.Color {
        SwiftUI.Color(uiColor: .tertiaryLabel)
    }
}
