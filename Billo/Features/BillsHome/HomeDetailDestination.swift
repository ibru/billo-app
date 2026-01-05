//
//  HomeDetailDestination.swift
//  Billo
//
//  Created by Jiri Urbasek on 12/30/25.
//

import SwiftData

enum HomeDetailDestination: Hashable {
    case bill(PersistentIdentifier)

    case paymentHistory
    case payment(PersistentIdentifier)

    case incomeList
    case income(PersistentIdentifier)

    case charts
    case dataExport
}

