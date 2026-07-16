//
//  ModelContext+ExistingModel.swift
//  Billo
//
//  Created by Jiri Urbasek on 07/16/26.
//

import Foundation
import SwiftData

extension ModelContext {
    /// Resolves a `PersistentIdentifier` only if its record still exists in
    /// the store. Unlike `model(for:)` — which returns the still-registered
    /// zombie instance for a deleted record and traps on the first property
    /// read — this refetches by ID, so deleted models resolve to `nil`.
    ///
    /// Throws on fetch failure so callers can tell "record is gone" apart
    /// from "store couldn't answer" — destructive reactions (like pruning
    /// navigation state) must only act on a positive `nil`.
    ///
    /// The fetch honors pending changes: an inserted-but-unsaved model still
    /// resolves, and a deleted-but-unsaved one already returns `nil` (both
    /// pinned by `HomeDetailDestinationValidityTests`).
    func existingModel<T: PersistentModel>(for identifier: PersistentIdentifier, of type: T.Type) throws -> T? {
        var descriptor = FetchDescriptor<T>(predicate: #Predicate { $0.persistentModelID == identifier })
        descriptor.fetchLimit = 1
        return try fetch(descriptor).first
    }
}
