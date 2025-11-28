//  Created by Jiri Urbasek on 11/27/25.

import Foundation

enum DefaultCategoryIdentifier: String, CaseIterable, Codable, Sendable {
    case utilities
    case subscriptions
    case housing
    case insurance
    case loans
    case other

    var displayName: String {
        switch self {
        case .utilities: return "Utilities"
        case .subscriptions: return "Subscriptions"
        case .housing: return "Housing"
        case .insurance: return "Insurance"
        case .loans: return "Loans"
        case .other: return "Other"
        }
    }

    var iconToken: String {
        switch self {
        case .utilities: return "utility"
        case .subscriptions: return "subscriptions"
        case .housing: return "housing"
        case .insurance: return "insurance"
        case .loans: return "loans"
        case .other: return "other"
        }
    }

    var colorToken: String { iconToken }

    var sortOrder: Int {
        switch self {
        case .utilities: return 0
        case .subscriptions: return 1
        case .housing: return 2
        case .insurance: return 3
        case .loans: return 4
        case .other: return 5
        }
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
