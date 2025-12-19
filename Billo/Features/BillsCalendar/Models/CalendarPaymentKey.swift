//  Created by Jiri Urbasek on 12/19/25.

import Foundation
import SwiftData

struct CalendarPaymentKey: Hashable {
    let billID: PersistentIdentifier
    let occurrenceDay: Date
}

