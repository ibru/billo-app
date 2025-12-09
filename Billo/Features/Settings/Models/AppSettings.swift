//  Created by Jiri Urbasek on 12/09/25.

import SwiftData
import Foundation

@Model
final class AppSettings {
    var currencyCode: String?
    var lastUpdatedDate: Date

    init(currencyCode: String? = nil) {
        self.currencyCode = currencyCode
        self.lastUpdatedDate = Date()
    }
}

extension AppSettings {
    /// Returns the singleton AppSettings instance, creating one if it doesn't exist.
    static func current(in context: ModelContext) -> AppSettings? {
        let descriptor = FetchDescriptor<AppSettings>()
        return try? context.fetch(descriptor).first
    }

    /// Returns or creates the singleton AppSettings instance.
    static func getOrCreate(in context: ModelContext) -> AppSettings {
        if let existing = current(in: context) {
            return existing
        }
        let newSettings = AppSettings()
        context.insert(newSettings)
        return newSettings
    }
}
