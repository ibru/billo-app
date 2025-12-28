//  Created by Jiri Urbasek on 12/28/25.

import Foundation

extension Int {
    func localizedOrdinal(locale: Locale = .autoupdatingCurrent) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

