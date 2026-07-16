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

extension HomeDetailDestination {
    /// False when the destination points at a record that no longer exists in
    /// the store (deleted locally or via CloudKit sync). Navigation state must
    /// drop such destinations instead of rendering a detail view around an
    /// invalidated model instance, whose property reads are fatal errors.
    ///
    /// Fails open: a fetch error treats the destination as valid, because the
    /// callers' reaction to `false` is destructive (pruning selection and
    /// path) and must only happen on a positive "record is gone" signal.
    func isValid(in modelContext: ModelContext) -> Bool {
        do {
            switch self {
            case .bill(let id):
                return try modelContext.existingModel(for: id, of: Bill.self) != nil
            case .occurrence(let id):
                return try modelContext.existingModel(for: id, of: IssuedOccurrence.self) != nil
            case .payment(let id):
                return try modelContext.existingModel(for: id, of: PaymentEntry.self) != nil
            case .income(let id):
                return try modelContext.existingModel(for: id, of: Income.self) != nil
            case .incomeOccurrence(let id):
                return try Self.visibleIncomeOccurrence(for: id, in: modelContext) != nil
            case .paymentHistory, .incomeList, .charts, .dataExport:
                return true
            }
        } catch {
            Logger.log("Destination validity check failed, treating as valid: \(error)", level: .error)
            return true
        }
    }

    /// Single rule for resolving a user-visible income occurrence, shared by
    /// validity checks and destination rendering so the two can't drift.
    /// Occurrence "deletion" is a soft-skip (`isExcluded`, the row stays in
    /// the store) — excluded rows count as gone, matching what the user sees.
    static func visibleIncomeOccurrence(
        for identifier: PersistentIdentifier,
        in modelContext: ModelContext
    ) throws -> IncomeOccurrence? {
        guard let occurrence = try modelContext.existingModel(for: identifier, of: IncomeOccurrence.self),
              occurrence.isExcluded == false else {
            return nil
        }
        return occurrence
    }

    /// Pure pruning decision for navigation state pointing at deleted records:
    /// an invalid selection clears entirely (its path is meaningless without
    /// its root), and the path is trimmed from its FIRST invalid element —
    /// keeping a later valid entry would silently reparent it under a
    /// different hierarchy.
    nonisolated static func prunedNavigation(
        selection: HomeDetailDestination?,
        path: [HomeDetailDestination],
        isValid: (HomeDetailDestination) -> Bool
    ) -> (selection: HomeDetailDestination?, path: [HomeDetailDestination]) {
        if let selection, isValid(selection) == false {
            return (nil, [])
        }
        var prunedPath = path
        if let firstInvalid = path.firstIndex(where: { isValid($0) == false }) {
            prunedPath.removeSubrange(firstInvalid...)
        }
        return (selection, prunedPath)
    }
}

