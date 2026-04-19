//  Created by Jiri Urbasek on 04/19/26.

import Foundation
import SwiftData

/// Resolves where a calendar payment row should navigate.
///
/// A payment row points at:
/// - the live Bill detail if the bill still exists, or
/// - the read-only Occurrence detail when the bill was deleted but the
///   IssuedOccurrence snapshot survived (`.nullify` on `Bill.issuedOccurrences`),
/// - nothing at all if neither is available (defensive fallback).
enum CalendarPaymentRouting {
    static func destination(for payment: PaymentEntry) -> HomeDetailDestination? {
        if let billID = payment.bill?.persistentModelID {
            return .bill(billID)
        }
        if let occurrenceID = payment.issuedOccurrence?.persistentModelID {
            return .occurrence(occurrenceID)
        }
        return nil
    }
}
