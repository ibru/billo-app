//
//  DeletedModelGuard.swift
//  Billo
//
//  Created by Jiri Urbasek on 07/16/26.
//

import SwiftData
import SwiftUI

/// Renders `content` only while `model`'s backing record still exists.
///
/// A SwiftData model can be invalidated while a view holding it is mounted
/// (deleted on another device via CloudKit sync, or deleted locally while a
/// split-view detail column keeps showing it). After invalidation, `isDeleted`
/// and `modelContext` are the only safe reads — any persisted-property access
/// is a fatal error. Every detail view that retains a `PersistentModel` must
/// gate its whole body through this guard; `content` is a `@ViewBuilder`
/// closure so nothing touches the model unless the record is still present.
///
/// The guard is deliberately passive: `isDeleted`/`modelContext` are not
/// observation-tracked, so the fallback appears on the NEXT body evaluation
/// after the delete, not at deletion time. That is sufficient — a crash
/// requires a property read, reads only happen during body evaluation, and
/// every evaluation reaches this check first. Actively unmounting stale
/// views is navigation's job (`pruneDeletedDestinations`).
///
/// Invariant for adopting views: do NOT read persisted properties in `init`
/// (e.g. to seed `@State`) — `init` runs before any guard. Use the
/// invalidation-safe reads first, or defer the read into `content`.
struct DeletedModelGuard<Model: PersistentModel, Content: View>: View {
    let model: Model
    let notFoundTitle: LocalizedStringKey
    let notFoundDescription: LocalizedStringKey
    @ViewBuilder let content: () -> Content

    var body: some View {
        if model.isDeleted || model.modelContext == nil {
            ContentUnavailableView(
                notFoundTitle,
                systemImage: "exclamationmark.triangle",
                description: Text(notFoundDescription)
            )
        } else {
            content()
        }
    }
}
