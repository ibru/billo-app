//  Created by Jiri Urbasek on 12/02/25.

import Foundation
import CryptoKit

struct NotificationIdentifier: Equatable, Sendable {
    let billIDHash: String
    let occurrenceTimestamp: Int
    let offsetDays: Int

    /// Format: "billo.r.{12-char-hash}_{timestamp}_{offset}"
    /// Example: "billo.r.a1b2c3d4e5f6_789012345_3" (max ~35 chars)
    var stringValue: String {
        "billo.r.\(billIDHash)_\(occurrenceTimestamp)_\(offsetDays)"
    }

    /// Prefix for all reminders of a specific bill
    static func prefix(forBillIDHash hash: String) -> String {
        "billo.r.\(hash)_"
    }

    /// Parses notification identifier back to components
    static func parse(_ identifier: String) -> NotificationIdentifier? {
        guard identifier.hasPrefix("billo.r.") else { return nil }

        let remainder = String(identifier.dropFirst("billo.r.".count))
        let components = remainder.split(separator: "_")

        guard components.count == 3,
              let timestamp = Int(components[1]),
              let offset = Int(components[2]) else {
            return nil
        }

        return NotificationIdentifier(
            billIDHash: String(components[0]),
            occurrenceTimestamp: timestamp,
            offsetDays: offset
        )
    }

    /// Creates 12-character hex hash of input string
    static func shortHash(of string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        // Take first 6 bytes = 12 hex characters
        return hash.prefix(6).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Constants

extension NotificationIdentifier {
    static let legacyDigestIdentifier = "billo.digest"
    static let digestPrefix = "billo.digest."

    static func digestIdentifier(for date: Date, calendar: Calendar) -> String {
        let dayStart = calendar.startOfDay(for: date)
        let timestamp = Int(dayStart.timeIntervalSinceReferenceDate)
        return "\(digestPrefix)\(timestamp)"
    }

    static func isDigestIdentifier(_ identifier: String) -> Bool {
        identifier == legacyDigestIdentifier || identifier.hasPrefix(digestPrefix)
    }
}
