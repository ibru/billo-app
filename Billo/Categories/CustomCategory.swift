//  Created by Jiri Urbasek on 11/27/25.

import SwiftData
import Foundation

@Model
final class CustomCategory {
    var id: String = UUID().uuidString
    var name: String = ""
    /// Literal SF Symbol name chosen by the user (e.g. "pawprint.fill").
    var iconToken: String = "tag"
    /// "#RRGGBB" hex string, normally one of
    /// `DesignSystem.Color.CategoryPalette.swatches`.
    var colorHex: String = "#8E8E93"
    var isArchived: Bool = false
    var archivedAt: Date?
    var replacementIdentifier: String?
    var createdAt: Date = Date()

    init(
        id: String = UUID().uuidString,
        name: String,
        iconToken: String,
        colorHex: String,
        isArchived: Bool = false,
        archivedAt: Date? = nil,
        replacementIdentifier: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconToken = iconToken
        self.colorHex = colorHex
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.replacementIdentifier = replacementIdentifier
        self.createdAt = createdAt
    }
}
