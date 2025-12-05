//  Created by Jiri Urbasek on 11/26/25.

import SwiftUI

enum DesignSystem {
    enum Spacing {
        static let extraSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }

    enum Color {
        static let overdueStatus = SwiftUI.Color.red
        static let dueTodayStatus = SwiftUI.Color.red
        static let upcomingStatus = SwiftUI.Color.primary
        static let paidStatus = SwiftUI.Color.gray

        // Time-span based colors
        static let dueTodayOrOverdue = SwiftUI.Color.red
        static let dueWithin7Days = SwiftUI.Color.orange
        static let dueWithin30Days = SwiftUI.Color.yellow
        static let dueLater = SwiftUI.Color.primary

        static let categoryUtility = SwiftUI.Color.blue
        static let categorySubscriptions = SwiftUI.Color.purple
        static let categoryHousing = SwiftUI.Color.green
        static let categoryInsurance = SwiftUI.Color.orange
        static let categoryLoans = SwiftUI.Color.red
        static let categoryOther = SwiftUI.Color.gray

        static func statusColor(for status: BillStatus) -> SwiftUI.Color {
            switch status {
            case .overdue: return overdueStatus
            case .dueToday: return dueTodayStatus
            case .upcoming: return upcomingStatus
            case .partiallyPaid: return SwiftUI.Color.orange
            case .paid: return paidStatus
            }
        }

        static func timeSpanColor(for dueDate: Date, relativeTo referenceDate: Date, calendar: Calendar) -> SwiftUI.Color {
            let startOfToday = calendar.startOfDay(for: referenceDate)
            let startOfDueDate = calendar.startOfDay(for: dueDate)

            // Check if overdue or due today
            if startOfDueDate <= startOfToday {
                return dueTodayOrOverdue
            }

            // Calculate days until due
            let daysUntilDue = calendar.dateComponents([.day], from: startOfToday, to: startOfDueDate).day ?? 0

            if daysUntilDue <= 7 {
                return dueWithin7Days
            } else if daysUntilDue <= 30 {
                return dueWithin30Days
            } else {
                return dueLater
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
