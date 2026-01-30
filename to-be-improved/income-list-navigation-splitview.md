# Income List Navigation (Split View) — Investigation & Fix Guide

## Symptom
- Tapping an income row in **Income list** does nothing.
- Repro on **iPhone (compact)** and **iPad**.
- Xcode console warning (observed on iPhone):
  > A NavigationLink is presenting a value of type “HomeDetailDestination”. The matching navigationDestination declaration is in the detail column, so it attempts to target the next column. There is no next column after the detail column.
  > Did you mean to put the navigationDestination inside a NavigationStack or else in a prior column?

## Root Cause (most likely)
`IncomeListView` uses a **value-based NavigationLink** with `HomeDetailDestination`:

```swift
NavigationLink(value: HomeDetailDestination.income(income.persistentModelID)) { ... }
```

`HomeDetailDestination` is also used for **split-view column navigation** in `BillsHomeSwitchView`:
- `NavigationSplitView { master } detail: { NavigationStack(...).navigationDestination(for: HomeDetailDestination.self) }`
- The **navigationDestination for `HomeDetailDestination` lives in the detail column**.

When the Income list itself is already displayed in the **detail column**, a `NavigationLink` of the same type attempts to push into the **next column** (which does not exist). This matches the warning and explains the “tap does nothing” behavior.

## Confirmed Repro
- iPhone 17 Pro (iOS 26.2): open Income list via the bottom pill → tap income row → no navigation.
- iPad (A16, iOS 26.2): open Income list in detail → tap income row → no navigation.

## Fix Options (choose one)

### Option A — Use a **local destination type** for Income list
Make navigation *within Income list* independent of split-view column navigation.

- Introduce a dedicated enum (e.g., `IncomeDetailDestination`).
- Add a local `.navigationDestination` inside `IncomeListView`.
- Update Income row links to use the local destination type.

Pros:
- Clean separation of “split-view destination” vs “detail-in-list destination”.
- Works consistently on iPhone/iPad/Mac.

Cons:
- Adds a new destination type.

### Option B — Use explicit destination NavigationLink
Replace the value-based link with:

```swift
NavigationLink {
    IncomeDetailView(income: income)
} label: {
    IncomeRowView(income: income)
}
```

Pros:
- Fast, minimal change.
- Avoids split-view routing entirely.

Cons:
- Less consistent with the rest of the app’s value-based navigation.
- Must ensure environment injections (`BillsModel`, `modelContext`) are set appropriately.

### Option C — Push Income list and detail inside its own NavigationStack
Wrap IncomeListView with its own `NavigationStack` (or provide one when presenting it), then use **local navigation** within that stack (either Option A or B).

Pros:
- Keeps navigation scoped.

Cons:
- Can add nested stacks if not carefully placed.

## Recommendation
**Option A** is the safest and most consistent long-term fix: separate split-view navigation (`HomeDetailDestination`) from “detail-in-list” navigation.

If you want the smallest diff, **Option B** is quickest.

## Notes
- Do not remove `HomeDetailDestination` usage — it still makes sense for the split-view top-level routing.
- The warning is a strong signal that the link’s destination is being resolved against the split-view column system rather than a local stack.
