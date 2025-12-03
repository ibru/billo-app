//  Created by Jiri Urbasek on 12/02/25.

import Foundation

enum BadgeMode: Equatable, Codable, Hashable, Sendable {
    case never
    case dueAndOverdue
    case daysBefore(Int)  // 1,3,5,7
}
