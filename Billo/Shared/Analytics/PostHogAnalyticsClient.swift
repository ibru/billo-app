//  Created by Jiri Urbasek on 07/10/26.

import Foundation
import PostHog

final class PostHogAnalyticsClient: AnalyticsClient {
    private static let iso8601Formatter = ISO8601DateFormatter()

    func capture(event: String, properties: [String: Any]) {
        PostHogSDK.shared.capture(event, properties: sanitize(properties))
    }

    func screen(name: String, properties: [String: Any]) {
        PostHogSDK.shared.screen(name, properties: sanitize(properties))
    }

    func register(superProperties: [String: Any]) {
        PostHogSDK.shared.register(sanitize(superProperties))
    }

    func unregister(superProperty key: String) {
        PostHogSDK.shared.unregister(key)
    }

    /// Safety net for property values PostHog can't serialize. Money is
    /// pre-converted to `Double` in `AnalyticsEvent.properties`; this only
    /// catches stragglers (e.g. a stray Date or enum) so capture never traps.
    private func sanitize(_ properties: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in properties {
            switch value {
            case is String, is Bool, is Int, is Double, is Float:
                result[key] = value
            case let date as Date:
                result[key] = Self.iso8601Formatter.string(from: date)
            case let values as [String]:
                result[key] = values
            case let values as [Int]:
                result[key] = values
            case let values as [Double]:
                result[key] = values
            default:
                result[key] = String(describing: value)
            }
        }
        return result
    }
}
