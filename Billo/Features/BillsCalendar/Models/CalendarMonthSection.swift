//  Created by Jiri Urbasek on 12/05/25.

import Foundation

struct CalendarMonthSection: Identifiable, Equatable {
    let id: String
    let title: String
    let items: [CalendarListItem]

    var isEmpty: Bool {
        items.count == 1 && items.first?.isEmptyMonth == true
    }
}
