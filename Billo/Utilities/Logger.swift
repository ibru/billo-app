//  Created by Jiri Urbasek on 09.12.2025.

import Foundation

enum LogLevel: String {
    case debug = "D"
    case info = "I"
    case warning = "W"
    case error = "E"
}

enum Logger {
    nonisolated static func log(
        _ message: String,
        level: LogLevel,
        function: String = #function
    ) {
        print("\(Date.now.ISO8601Format(.iso8601(timeZone: .autoupdatingCurrent, includingFractionalSeconds: true, dateSeparator: .dash, dateTimeSeparator: .space, timeSeparator: .colon))) [\(level.rawValue)] [\(function)] \(message)")
    }
}
