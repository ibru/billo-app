//  Created by Jiri Urbasek on 11/26/25.

import SwiftUI

enum DesignSystem {
    // MARK: - Spacing Scale
    enum Spacing {
        static let extraSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let mediumSmall: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }

    // MARK: - Corner Radii
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 24
        static let extraExtraLarge: CGFloat = 32
    }

    // MARK: - Shadow
    enum Shadow {
        /// Standard card shadow
        static let card: (color: SwiftUI.Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            color: SwiftUI.Color.black.opacity(0.08),
            radius: 12,
            x: 0,
            y: 4
        )

        /// Subtle card shadow for list items
        static let subtle: (color: SwiftUI.Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            color: SwiftUI.Color.black.opacity(0.06),
            radius: 4,
            x: 0,
            y: 2
        )
    }

    // MARK: - Card Styling
    enum Card {
        /// Left indicator bar width
        static let indicatorWidth: CGFloat = 4
        /// Left indicator bar corner radius
        static let indicatorCornerRadius: CGFloat = 2
    }

    // MARK: - Colors
    enum Color {
        // MARK: Base Palette (same in light/dark)
        /// Lighter green for paid/completed states (#34D068)
        static let green = paletteColor(0x34D068)

        /// Darker green for income and positive amounts (#0A8F3A)
        static let greenIncome = paletteColor(0x0A8F3A)

        /// Main yellow (#FFBC03)
        static let yellow = paletteColor(0xFFBC03)

        /// Main orange (#FB801C) - derived between yellow and red for urgency
        static let orange = paletteColor(0xFB801C)

        /// Main red (#F74435)
        static let red = paletteColor(0xF74435)

        /// Main blue (#69B6DD)
        static let blue = paletteColor(0x69B6DD)

        /// Neutral dark (#2E2F33)
        static let neutralDark = paletteColor(0x2E2F33)

        // MARK: Category Palette
        /// Hex strings for category colors. Single source for the predefined
        /// category colors and the custom-category swatch grid; persisted
        /// values (`CustomCategory.colorHex`) reference these strings.
        enum CategoryPalette {
            static let utilities = "#5856D6"       // Indigo
            static let subscriptions = "#FF6B6B"   // Coral
            static let housing = "#34C759"         // Green
            static let insurance = "#5AC8FA"       // Sky blue
            static let loans = "#FF9500"           // Amber
            static let transportation = "#007AFF"  // Blue
            static let phoneInternet = "#30B0C7"   // Teal
            static let health = "#FF2D55"          // Pink
            static let entertainment = "#AF52DE"   // Purple
            static let groceries = "#9BC53D"       // Lime
            static let education = "#A2845E"       // Brown
            static let family = "#FFCC00"          // Yellow
            static let pets = "#00C7BE"            // Mint
            static let taxesFees = "#C9366F"       // Raspberry
            static let other = "#8E8E93"           // Gray

            /// Swatches offered when creating a custom category.
            static let swatches: [String] = [
                utilities, transportation, insurance, phoneInternet, pets,
                housing, groceries, family, loans, subscriptions,
                health, taxesFees, entertainment, education, other
            ]
        }

        // MARK: - Helpers
        private static func paletteColor(_ hex: UInt32, alpha: Double = 1) -> SwiftUI.Color {
            let red = Double((hex >> 16) & 0xFF) / 255
            let green = Double((hex >> 8) & 0xFF) / 255
            let blue = Double(hex & 0xFF) / 255
            return SwiftUI.Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
        }

        // MARK: - Helper Functions
        static func statusColor(for status: BillStatus) -> SwiftUI.Color {
            switch status {
            case .overdue: return red
            case .dueToday: return red
            case .upcoming: return blue
            case .partiallyPaid: return orange
            case .paid: return green
            }
        }

        static func timeSpanColor(for dueDate: Date, relativeTo referenceDate: Date, calendar: Calendar) -> SwiftUI.Color {
            let startOfToday = calendar.startOfDay(for: referenceDate)
            let startOfDueDate = calendar.startOfDay(for: dueDate)

            // Check if overdue or due today
            if startOfDueDate <= startOfToday {
                return red
            }

            // Calculate days until due
            let daysUntilDue = calendar.dateComponents([.day], from: startOfToday, to: startOfDueDate).day ?? 0

            if daysUntilDue <= 7 {
                return orange
            } else if daysUntilDue <= 30 {
                return yellow
            } else {
                return neutralDark
            }
        }

    }
}

// MARK: - View Modifiers

extension View {
    /// Applies standard chart card styling with padding, background, and rounded corners
    func chartCardStyle() -> some View {
        self
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }

    /// Applies standard card shadow
    func cardShadow() -> some View {
        let shadow = DesignSystem.Shadow.card
        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }

    /// Applies subtle card shadow for list items
    func subtleShadow() -> some View {
        let shadow = DesignSystem.Shadow.subtle
        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }

    /// Red tint for destructive controls. The app-wide green tint
    /// (`BilloApp`) overrides the destructive role's implicit red, so every
    /// destructive button/swipe action must re-tint through this single
    /// modifier instead of ad-hoc `.tint(.red)` calls.
    func destructiveTint() -> some View {
        tint(DesignSystem.Color.red)
    }
}

// MARK: - Hex Colors

extension SwiftUI.Color {
    /// Parses a `"#RRGGBB"` hex string (leading `#` optional). Unparseable
    /// input falls back to the neutral category gray so a corrupt persisted
    /// value can never crash rendering.
    init(hex: String) {
        let sanitized = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard sanitized.count == 6, let value = UInt32(sanitized, radix: 16) else {
            // CategoryPalette.other (#8E8E93), inlined to keep the fallback non-recursive
            self.init(.sRGB, red: 0x8E / 255, green: 0x8E / 255, blue: 0x93 / 255, opacity: 1)
            return
        }

        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}
