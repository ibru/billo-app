//
//  DesignSystem+PlatformColors.swift
//  Billo
//
//  Created by Jiri Urbasek on 12/30/25.
//

import SwiftUI

import UIKit

extension DesignSystem.Color {
    // MARK: - System Background Colors
    static var background: SwiftUI.Color {
        SwiftUI.Color(uiColor: .systemBackground)
    }

    static var groupedBackground: SwiftUI.Color {
        SwiftUI.Color(uiColor: .systemGroupedBackground)
    }

    /// Card background uses fixed palette color for both light and dark.
    static var cardBackground: SwiftUI.Color {
        DesignSystem.Color.neutralDark
    }

    // MARK: - System Label Colors
    static var separator: SwiftUI.Color {
        SwiftUI.Color(uiColor: .separator)
    }

    static var tertiaryLabel: SwiftUI.Color {
        SwiftUI.Color(uiColor: .tertiaryLabel)
    }

    /// Secondary text color - matches system secondary label
    static var textSecondary: SwiftUI.Color {
        SwiftUI.Color(uiColor: .secondaryLabel)
    }
}
