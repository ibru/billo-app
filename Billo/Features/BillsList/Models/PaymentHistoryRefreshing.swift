//  Created by Jiri Urbasek on 11/27/25.

import Foundation

@MainActor
protocol PaymentHistoryRefreshing: AnyObject {
    func refresh() async throws
    func reloadVisibleWindow() async throws
}
