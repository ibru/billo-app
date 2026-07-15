//  Created by Jiri Urbasek on 05/12/26.

import Foundation

/// Cached UTC calendar for `utcDayKey`. Building a `Calendar` is expensive
/// (ICU setup) and the key is computed inside per-occurrence hot loops
/// (calendar/charts refresh), so it must not be re-created per call.
private nonisolated let utcGregorianCalendar: Calendar = {
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return utc
}()

extension Date {
    /// `YYYY-MM-DD` of this `Date`'s UTC day.
    ///
    /// **The key is the UTC day of the underlying instant — not the user's
    /// local calendar day.** Two devices that observe the same `Date` instance
    /// (the way CloudKit syncs `Date` values) will always compute the same
    /// string, so this is safe to use as identity. But the displayed local day
    /// for that same `Date` can differ across timezones: a local midnight
    /// entered in `Europe/Prague` falls on the prior UTC day, so the key
    /// trails the displayed day by one. If you need the displayed day to
    /// match the key, store the source `Date` at a normalized hour
    /// (e.g. local noon) so it cannot cross UTC midnight in either direction.
    ///
    /// `nonisolated` so it can be called from `@Model` types like `Bill` whose
    /// generated members are not main-actor-bound.
    nonisolated var utcDayKey: String {
        let components = utcGregorianCalendar.dateComponents([.year, .month, .day], from: self)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

/// Stable identity for a single occurrence of a recurring item.
///
/// Format: `<stableID>:<YYYY-MM-DD>` where the date portion is the UTC day of
/// the underlying `Date` instant (see `Date.utcDayKey`). This is the canonical
/// shape used by `IncomeOccurrence` today and is intentionally available to
/// any future @Model that wants the same identity contract.
///
/// All members are `nonisolated` — these are pure value-in/value-out helpers
/// and the `@Model` callers (`Bill`, `Income`) are themselves nonisolated.
enum OccurrenceKey {
    /// Composes a canonical occurrence key from its two parts.
    nonisolated static func make(stableID: String, date: Date) -> String {
        "\(stableID):\(date.utcDayKey)"
    }

    /// Prefix shared by every key for `stableID` — useful for the kind of
    /// `starts(with:)` predicate fetches the materializer needs to find all
    /// occurrences belonging to a parent.
    nonisolated static func prefix(forStableID stableID: String) -> String {
        "\(stableID):"
    }

    /// Recovers the parent `stableID` from a canonical key, or returns `nil`
    /// for a malformed key (one without the `:` separator).
    nonisolated static func stableID(from key: String) -> String? {
        guard let separator = key.firstIndex(of: ":") else { return nil }
        return String(key[..<separator])
    }
}
