//  Created by Jiri Urbasek on 12/05/25.

import Foundation

enum BillsHomeViewMode: String, CaseIterable, Identifiable {
    case list
    case calendar

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .list: "list.bullet"
        case .calendar: "calendar"
        }
    }

    var title: String {
        switch self {
        case .list: String(localized: "List")
        case .calendar: String(localized: "Calendar")
        }
    }
}
