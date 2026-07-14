//  Created by Jiri Urbasek on 04/19/26.

import Foundation
import SwiftData

/// Resolves where a calendar payment row should navigate.
///
/// A payment row points at:
/// - the live Bill detail if the bill still exists AND is visible under the
///   free-tier display cap (`isBillVisible`), or
/// - the read-only Occurrence detail when the bill was deleted — or is hidden
///   by the cap: historical payments stay visible, but must not open the
///   live detail of a bill the free tier can't see,
/// - nothing at all if neither is available (defensive fallback).
enum CalendarPaymentRouting {
    static func destination(
        for payment: PaymentEntry,
        isBillVisible: (PersistentIdentifier) -> Bool = { _ in true }
    ) -> HomeDetailDestination? {
        if let billID = payment.bill?.persistentModelID, isBillVisible(billID) {
            return .bill(billID)
        }
        if let occurrenceID = payment.issuedOccurrence?.persistentModelID {
            return .occurrence(occurrenceID)
        }
        return nil
    }
}
