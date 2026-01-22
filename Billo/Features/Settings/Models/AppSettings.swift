//  Created by Jiri Urbasek on 12/09/25.

import SwiftData
import Foundation

@Model
final class AppSettings {
    var currencyCode: String?
    var lastUpdatedDate: Date = Date()

    init(currencyCode: String? = nil) {
        self.currencyCode = currencyCode
        self.lastUpdatedDate = Date()
    }
}

extension AppSettings {
    /// Returns the singleton AppSettings instance, creating one if it doesn't exist.
    static func current(in context: ModelContext) -> AppSettings? {
        let descriptor = FetchDescriptor<AppSettings>(
            sortBy: [SortDescriptor(\.lastUpdatedDate, order: .reverse)]
        )
        return try? context.fetch(descriptor).first
    }

    /// Returns or creates the singleton AppSettings instance.
    /// Handles CloudKit sync duplicates by keeping the most recently updated record.
    static func getOrCreate(in context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>(
            sortBy: [SortDescriptor(\.lastUpdatedDate, order: .reverse)]
        )

        do {
            let all = try context.fetch(descriptor)
            if let primary = all.first {
                // Collect duplicates first, then delete after iteration
                // to avoid mutating during enumeration
                let duplicates = Array(all.dropFirst())
                for duplicate in duplicates {
                    context.delete(duplicate)
                }
                return primary
            }
        } catch {
            // Fall through to create new
        }

        let newSettings = AppSettings()
        context.insert(newSettings)
        return newSettings
    }
}
