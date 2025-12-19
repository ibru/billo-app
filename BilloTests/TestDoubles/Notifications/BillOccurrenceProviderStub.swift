//  Created by Jiri Urbasek on 12/02/25.

import Foundation
import SwiftData
@testable import Billo

// MARK: - BillOccurrenceProviderStub

final class BillOccurrenceProviderStub: BillOccurrenceProviding, @unchecked Sendable {
    struct UnpaidOccurrencesCall: Sendable {
        let billsCount: Int
        let horizonDays: Int
        let referenceDate: Date
    }

    var stubbedOccurrences: [BillOccurrence] = []
    private(set) var unpaidOccurrencesCalls: [UnpaidOccurrencesCall] = []

    func unpaidOccurrences(
        from bills: [Bill],
        referenceDate: Date,
        horizonDays: Int,
        calendar: Calendar
    ) async -> [BillOccurrence] {
        unpaidOccurrencesCalls.append(
            UnpaidOccurrencesCall(
                billsCount: bills.count,
                horizonDays: horizonDays,
                referenceDate: referenceDate
            )
        )

        let allowedBillIDs = Set(bills.map { String(describing: $0.persistentModelID) })
        guard let horizonEnd = calendar.date(byAdding: .day, value: horizonDays, to: referenceDate) else {
            return []
        }

        return stubbedOccurrences.filter { occurrence in
            allowedBillIDs.contains(String(describing: occurrence.bill.persistentModelID)) && occurrence.dueDate <= horizonEnd
        }
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
