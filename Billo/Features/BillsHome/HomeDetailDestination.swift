//
//  HomeDetailDestination.swift
//  Billo
//
//  Created by Jiri Urbasek on 12/30/25.
//

import SwiftData

enum HomeDetailDestination: Hashable {
    case bill(PersistentIdentifier)
    case occurrence(PersistentIdentifier)

    case paymentHistory
    case payment(PersistentIdentifier)

    case incomeList
    case income(PersistentIdentifier)
    /// Single persisted past `IncomeOccurrence`. Routes to a detail view that
    /// allows correcting that row's amount or removing just that one
    /// occurrence — without touching the parent `Income` or its future
    /// projection.
    case incomeOccurrence(PersistentIdentifier)

    case charts
    case dataExport
}

