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

        // MARK: Category Colors
        static let categoryUtility = paletteColor(0x5856D6)   // Indigo
        static let categorySubscriptions = paletteColor(0xFF6B6B)  // Coral
        static let categoryHousing = paletteColor(0x34C759)   // Green
        static let categoryInsurance = paletteColor(0x5AC8FA)  // Sky blue
        static let categoryLoans = paletteColor(0xFF9500)     // Amber
        static let categoryOther = paletteColor(0x8E8E93)     // Gray

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

        static func categoryColor(for token: String) -> SwiftUI.Color {
            switch DesignSystem.canonicalCategoryToken(from: token) {
            case "utility": return categoryUtility
            case "subscriptions": return categorySubscriptions
            case "housing": return categoryHousing
            case "insurance": return categoryInsurance
            case "loans": return categoryLoans
            default: return categoryOther
            }
        }
    }

    // MARK: - Icons
    enum Icon {
        static let categoryUtility = "bolt.fill"
        static let categorySubscriptions = "arrow.triangle.2.circlepath"
        static let categoryHousing = "house.fill"
        static let categoryInsurance = "shield.fill"
        static let categoryLoans = "creditcard.fill"
        static let categoryOther = "ellipsis.circle.fill"

        static func categoryIcon(for token: String) -> String {
            switch DesignSystem.canonicalCategoryToken(from: token) {
            case "utility": return categoryUtility
            case "subscriptions": return categorySubscriptions
            case "housing": return categoryHousing
            case "insurance": return categoryInsurance
            case "loans": return categoryLoans
            default: return categoryOther
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
}

// MARK: - Helpers

extension DesignSystem {
    static func canonicalCategoryToken(from rawToken: String) -> String {
        let normalized = normalizeCategoryToken(rawToken)

        switch normalized {
        case "utility", "utilities", "energy", "water":
            return "utility"
        case "subscription", "subscriptions", "streaming", "services":
            return "subscriptions"
        case "housing", "rent", "mortgage", "home":
            return "housing"
        case "insurance", "assurance":
            return "insurance"
        case "loan", "loans", "debt", "creditcard":
            return "loans"
        case "other", "misc", "miscellaneous":
            return "other"
        default:
            return normalized.isEmpty ? "other" : normalized
        }
    }

    fileprivate static func normalizeCategoryToken(_ rawToken: String) -> String {
        let trimmed = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }

        let folded = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let lowercase = folded.lowercased()
        let sanitized = lowercase
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")

        return sanitized
    }
}
