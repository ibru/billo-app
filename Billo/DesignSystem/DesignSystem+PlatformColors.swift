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
