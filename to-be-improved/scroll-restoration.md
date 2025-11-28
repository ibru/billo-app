# Scroll Restoration Without Delays

## Current Situation
`BillsListView` preserves scroll position when users toggle the payment history section. The implementation works, but it relies on two `Task.sleep` calls (50 ms and 80 ms) to let SwiftUI finish recalculating layout before calling `ScrollViewProxy.scrollTo`. This technique is pragmatic, yet it introduces a race condition if layout takes longer on older devices and it complicates reasoning for junior teammates (“why do we sleep here?”).

## Why This Is a Problem
1. **Timing Fragility** – Artificial delays depend on device performance. If SwiftUI needs more than ~50 ms to rebuild the list, we may still jump to the wrong offset.
2. **Readability** – Future maintainers might remove or shorten the sleeps without understanding their purpose, reintroducing the jump the feature was designed to prevent.
3. **Testing Difficulty** – It is hard to deterministically test code paths that rely on timing heuristics.

## Recommended Improvement
Migrate the list to SwiftUI’s native scroll-position APIs instead of manual sleeps:

1. **Adopt `ScrollView` + `LazyVStack`**
   - Replace the `List` with a `ScrollView` (with `.scrollTargetLayout()`).
   - Wrap all rows in a `LazyVStack` so we can reference item IDs directly.

2. **Bind Scroll Position**
   - Add `@State private var scrollID: BillsListAnchor?`.
   - Apply `.scrollPosition(id: $scrollID)` to the `ScrollView`.
   - Update `scrollID` whenever our visible-row preference reports the top-most anchor.

3. **Restore Without Sleeping**
   - When toggling history, set `scrollID = anchorToRestore` inside `withAnimation(.none)`.
   - SwiftUI will drive the scroll back to that ID as soon as layout stabilizes, so there’s no need to pause the task manually.

4. **Recreate List affordances**
   - Reimplement swipe actions (e.g., using custom gesture overlays) or wrap rows in `ListRowBackground`-style modifiers so we keep parity with the old `List` look.

## Guidance for a Junior Developer
1. **Prototype in a Separate View** – Start by creating a toy `ScrollView` that uses `.scrollPosition(id:)` to move between fake rows. This will build intuition before touching the production list.
2. **Switch Incrementally** – Replace the `List` only after you have the scroll-position prototype working. Keep the existing anchor preference key to feed `scrollID`.
3. **Remove `Task.sleep`** – Once the scroll position binding works, delete both sleep calls; the binding becomes the single source of truth for restoration.
4. **Regression Tests** – Run the full UI regression checklist (toggle at top/middle/bottom; rapid toggles). Pay special attention to swipe actions and list separators, since they need to be recreated manually when leaving `List`.

## Acceptance Criteria
- Toggling payment history never calls `Task.sleep`.
- `scrollID` changes traceable in logging/assertions when the top-most row shifts.
- Manual testing on simulator shows zero jump regardless of device performance.
- Swipe actions and section headers remain functional after the switch to `ScrollView`.
