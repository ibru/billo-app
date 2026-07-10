//  Created by Jiri Urbasek on 11/27/25.

import Foundation

enum DefaultCategoryIdentifier: String, CaseIterable, Codable, Sendable {
    // Declaration order defines `sortOrder`. Raw values are persisted in
    // `Bill.categoryIdentifierRawValue` — never change existing ones.
    case utilities
    case subscriptions
    case housing
    case insurance
    case loans
    case transportation
    case phoneInternet
    case health
    case entertainment
    case groceries
    case education
    case family
    case pets
    case taxesFees
    case other

    var displayName: String {
        switch self {
        case .utilities: return String(localized: "Utilities")
        case .subscriptions: return String(localized: "Subscriptions")
        case .housing: return String(localized: "Housing")
        case .insurance: return String(localized: "Insurance")
        case .loans: return String(localized: "Loans")
        case .transportation: return String(localized: "Transportation")
        case .phoneInternet: return String(localized: "Phone & Internet")
        case .health: return String(localized: "Health")
        case .entertainment: return String(localized: "Entertainment")
        case .groceries: return String(localized: "Groceries")
        case .education: return String(localized: "Education")
        case .family: return String(localized: "Family & Kids")
        case .pets: return String(localized: "Pets")
        case .taxesFees: return String(localized: "Taxes & Fees")
        case .other: return String(localized: "Other")
        }
    }

    var systemImageName: String {
        switch self {
        case .utilities: return "bolt.fill"
        case .subscriptions: return "arrow.triangle.2.circlepath"
        case .housing: return "house.fill"
        case .insurance: return "shield.fill"
        case .loans: return "creditcard.fill"
        case .transportation: return "car.fill"
        case .phoneInternet: return "antenna.radiowaves.left.and.right"
        case .health: return "cross.case.fill"
        case .entertainment: return "popcorn.fill"
        case .groceries: return "basket.fill"
        case .education: return "graduationcap.fill"
        case .family: return "figure.2.and.child.holdinghands"
        case .pets: return "pawprint.fill"
        case .taxesFees: return "building.columns.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var colorHex: String {
        typealias Palette = DesignSystem.Color.CategoryPalette
        switch self {
        case .utilities: return Palette.utilities
        case .subscriptions: return Palette.subscriptions
        case .housing: return Palette.housing
        case .insurance: return Palette.insurance
        case .loans: return Palette.loans
        case .transportation: return Palette.transportation
        case .phoneInternet: return Palette.phoneInternet
        case .health: return Palette.health
        case .entertainment: return Palette.entertainment
        case .groceries: return Palette.groceries
        case .education: return Palette.education
        case .family: return Palette.family
        case .pets: return Palette.pets
        case .taxesFees: return Palette.taxesFees
        case .other: return Palette.other
        }
    }

    var sortOrder: Int {
        Self.allCases.firstIndex(of: self) ?? Self.allCases.count
    }
}

enum CategoryIdentifier: Hashable, Codable, Sendable, Identifiable {
    case predefined(DefaultCategoryIdentifier)
    case custom(String)

    var id: String { rawValue }

    nonisolated var rawValue: String {
        switch self {
        case .predefined(let identifier):
            return identifier.rawValue
        case .custom(let value):
            return value
        }
    }

    nonisolated var isDefault: Bool {
        if case .predefined = self { return true }
        return false
    }

    nonisolated init?(rawValue: String) {
        if let predefined = DefaultCategoryIdentifier(rawValue: rawValue) {
            self = .predefined(predefined)
        } else if rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        } else {
            self = .custom(rawValue)
        }
    }

    nonisolated var analyticsKey: String {
        switch self {
        case .predefined(let identifier):
            return "default.\(identifier.rawValue)"
        case .custom:
            return "custom"
        }
    }

}
