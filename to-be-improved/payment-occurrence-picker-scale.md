# Occurrence Picker Scale Problem (Future Improvement)

## What happens
When a bill has many unpaid occurrences, the "For Occurrence" picker in the Mark as Paid sheet can surface a very long list. The current v2 design removes hard caps on candidates, so for dense schedules the inline picker could show dozens or hundreds of rows.

## Where it occurs
- **Daily recurrence** with more than ~30–60 days unpaid (e.g., user stopped paying daily coffee subscription for 3 months).
- **Weekly recurrence** with many missed weeks plus future instances (e.g., 20+ weeks overdue and several future weeks visible).
- **Long lookback/lookahead windows**: frequency-based windows (e.g., ±3 months daily, ±6/12 months weekly) intentionally return all unpaid dates to preserve accuracy.

## Why it matters (but low priority)
- Usability: a giant picker is hard to scan and slow to scroll.
- Error risk: user may pick the wrong date when the list is crowded.
- Performance: SwiftUI picker/List still handles hundreds of rows, so this is mostly a UX, not correctness, issue. It affects a minority of heavy-delinquency cases, so we are choosing not to optimize immediately.

## Suggested future fix (keeps correctness, improves UX)
1) **Keep one authoritative list**: `allCandidates` contains every unpaid occurrence, sorted by absolute day distance from `datePaid` (closest first).
2) **Show a short list by default**: `displayedCandidates = allCandidates.prefix(20)` in the inline picker.
3) **Overflow affordance**: if `allCandidates.count > displayedCandidates.count`, add a row/button labeled `Show all occurrences… (+N more)`.
4) **Full list sheet**: tapping the affordance opens a sheet with a searchable List over `allCandidates`, still distance-sorted; selection writes back to the shared `selectedOccurrence` binding.
5) **Optional jump-to-date**: include a compact DatePicker in the sheet that auto-scrolls/auto-selects the closest unpaid occurrence to the chosen date, avoiding long scrolls.

This approach preserves the anchored generation (no data loss), avoids truncation errors, and contains the UX cost to rare high-volume scenarios while keeping the default flow fast for typical users.
