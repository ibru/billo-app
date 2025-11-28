//  Created by Jiri Urbasek on 11/27/25.

import SwiftData
import Foundation

@Model
final class CustomCategory {
    @Attribute(.unique) var id: String
    var name: String
    var iconToken: String
    var colorToken: String
    var isArchived: Bool
    var archivedAt: Date?
    var replacementIdentifier: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        iconToken: String,
        colorToken: String,
        isArchived: Bool = false,
        archivedAt: Date? = nil,
        replacementIdentifier: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconToken = iconToken
        self.colorToken = colorToken
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.replacementIdentifier = replacementIdentifier
        self.createdAt = createdAt
    }
}
