//  Created by Jiri Urbasek on 09.12.2025.

import Foundation

enum LogLevel: String {
    case debug = "D"
    case info = "I"
    case warning = "W"
    case error = "E"
}

enum Logger {
    /// `message` is an autoclosure so skipped log levels pay no string
    /// interpolation or date-formatting cost — several call sites log per
    /// bill/month inside refresh loops that run on the main actor.
    nonisolated static func log(
        _ message: @autoclosure () -> String,
        level: LogLevel,
        function: String = #function
    ) {
        #if !DEBUG
        guard level != .debug else { return }
        #endif
        print("\(Date.now.ISO8601Format(.iso8601(timeZone: .autoupdatingCurrent, includingFractionalSeconds: true, dateSeparator: .dash, dateTimeSeparator: .space, timeSeparator: .colon))) [\(level.rawValue)] [\(function)] \(message())")
    }
}
