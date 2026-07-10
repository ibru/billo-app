//  Created by Jiri Urbasek on 07/10/26.

import Foundation
import Observation

@MainActor
@Observable
final class AnalyticsModel {
    private let client: any AnalyticsClient

    init(client: some AnalyticsClient = NoopAnalyticsClient()) {
        self.client = client
    }

    func screen(_ screen: AnalyticsScreen, properties: [String: Any] = [:]) {
        debugLog(type: "SCREEN", name: screen.rawValue, properties: properties)
        client.screen(name: screen.rawValue, properties: properties)
    }

    func capture(_ event: AnalyticsEvent) {
        debugLog(type: "EVENT", name: event.name, properties: event.properties)
        client.capture(event: event.name, properties: event.properties)
    }

    func register(superProperties: [String: Any]) {
        debugLog(type: "SUPER_PROPS", name: "register", properties: superProperties)
        client.register(superProperties: superProperties)
    }

    func unregister(superProperty key: String) {
        debugLog(type: "SUPER_PROPS", name: "unregister", properties: ["key": key])
        client.unregister(superProperty: key)
    }

    // MARK: - Debug Logging

    private func debugLog(type: String, name: String, properties: [String: Any]) {
        #if DEBUG
        let propertiesString = properties.isEmpty ? "(none)" : formatProperties(properties)
        print("[Analytics] \(type): \"\(name)\" | Properties: \(propertiesString)")
        #endif
    }

    private func formatProperties(_ properties: [String: Any]) -> String {
        properties
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
    }
}
