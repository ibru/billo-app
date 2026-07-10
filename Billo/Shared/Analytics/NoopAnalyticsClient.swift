//  Created by Jiri Urbasek on 07/10/26.

struct NoopAnalyticsClient: AnalyticsClient {
    func capture(event: String, properties: [String: Any]) {}
    func screen(name: String, properties: [String: Any]) {}
    func register(superProperties: [String: Any]) {}
    func unregister(superProperty key: String) {}
}
