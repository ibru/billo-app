//  Created by Jiri Urbasek on 09.12.2025.

import Foundation

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

enum Logger {
    nonisolated static func log(
        _ message: String,
        level: LogLevel,
        function: String = #function
    ) {
        print("[\(level.rawValue)] [\(function)] \(message)")
    }
}
