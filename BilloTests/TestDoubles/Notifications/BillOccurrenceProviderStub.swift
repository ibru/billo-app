//  Created by Jiri Urbasek on 12/02/25.

import Foundation
@testable import Billo

// MARK: - BillOccurrenceProviderStub

final class BillOccurrenceProviderStub: BillOccurrenceProviding, @unchecked Sendable {
    var stubbedOccurrences: [BillOccurrence] = []

    func unpaidOccurrences(
        from bills: [Bill],
        referenceDate: Date,
        horizonDays: Int,
        calendar: Calendar
    ) async -> [BillOccurrence] {
        stubbedOccurrences
    }

    // Factory helpers for tests
    static func returning(_ occurrences: [BillOccurrence]) -> BillOccurrenceProviderStub {
        let stub = BillOccurrenceProviderStub()
        stub.stubbedOccurrences = occurrences
        return stub
    }

    static func empty() -> BillOccurrenceProviderStub {
        BillOccurrenceProviderStub()
    }
}
