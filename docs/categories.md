# Category Catalog Guide

This document explains how Billo stores and renders bill categories as of the November 27, 2025 refactor.

## Core Concepts

- **CategoryIdentifier** – An enum that wraps the canonical default identifiers (`utilities`, `subscriptions`, etc.) plus a `.custom(String)` case for user-created categories. Bills persist the identifier string (`Bill.categoryIdentifierRawValue`) rather than a `Category` object, which keeps UI and analytics aligned.
- **CategoryCatalog** – A lightweight resolver that owns the source-controlled catalog metadata (names, icon tokens, color tokens, sort order) and memoizes default lookups. It merges SwiftData-backed `CustomCategory` overrides when displaying categories in the UI.
- **CustomCategory** – The SwiftData model representing any user-defined or renamed category. Each record stores the display name, icon/color tokens, archival state, and optional replacement identifier.

## Rendering Categories

1. Fetch active `CustomCategory` rows using `@Query(sort: \CustomCategory.name)`.
2. Use `CategoryCatalog.displayInfo(for:customCategories:)` to convert a `CategoryIdentifier?` into `CategoryDisplayInfo` (name + tokens + archival flags).
3. Use `CategoryCatalog.availableCategories(customCategories:)` to populate pickers. This returns defaults first (in their canonical order) followed by custom, non-archived entries sorted alphabetically.
4. Respect `CategoryDisplayInfo.isArchived` when deciding whether to show an item in selection UIs. Archived entries remain valid for history/reporting but should be hidden from pickers.

## Archiving Flow

- Set `CustomCategory.isArchived = true`, capture `archivedAt`, and optionally store `replacementIdentifier` to suggest a fallback.
- Bills keep their original identifier to preserve history. When rendering future selections, filter archived entries unless the user explicitly opts to show them.
- If a default identifier must be retired, bump the catalog version (see below) and run a lightweight migrator that remaps affected bills to another identifier or prompts the user.

## Catalog Versioning

- `CategoryCatalog.currentVersion` represents the semantic version of the bundled catalog (`2025.1` to start).
- `CategoryCatalogVersioning.ensureCurrentVersionApplied()` stores the last applied version in `UserDefaults` and invalidates resolver caches whenever the bundled version changes.
- When introducing new defaults or updating metadata, increment `currentVersion` and add the migrator logic closest to the change (e.g., inserting new categories or rotating tokens). Keep these migrators idempotent.

## Adding or Updating Categories

1. Extend `DefaultCategoryIdentifier` when adding a new default entry; supply its display name, icon token, color token, and sort order.
2. Update localization resources for any new default labels (currently English-only; wire to the localization script when translations exist).
3. Bump `CategoryCatalog.currentVersion` when changing default metadata.
4. If the change affects user-visible UI copy (e.g., new picker description), update any relevant SwiftUI strings and localization files.

## Testing Notes

- Prefer behavioral tests by seeding `Bill` instances with `CategoryIdentifier` values instead of storing SwiftData category entities.
- When previewing, use `.predefined(<identifier>)` for defaults or insert `CustomCategory` rows directly into the in-memory container for custom use cases.

Use this guide whenever you need to modify category behavior, add new defaults, or extend the resolver.
