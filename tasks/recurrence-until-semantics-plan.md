# Development Plan: Recurrence `until` Semantics Unification

Date: 2026-02-10
Owner: Billing core + Charts
Status: Draft for implementation

## 1) Context and Why This Exists

This is related to a separate issue from due-date normalization.

Problem:
- `Calendar.dateInterval(of: .month, for:)` returns a half-open interval: `[monthStart, nextMonthStart)`.
- Recurrence generation historically behaved as if `until` were inclusive.
- Passing `monthInterval.end` into inclusive generation can double-count boundary dates across adjacent months.

Observed symptom:
- Monthly trends/cash-flow can count an occurrence on month boundary in both months.

## 2) Is This a Big Rewrite?

No. This is a medium-scope semantic alignment, not an architectural rewrite.

Expected effort:
- Core behavior change is small (generator + wrappers).
- Main work is consistency updates in tests and boundary call sites.
- Risk is regression risk from mixed inclusive/exclusive assumptions, not implementation complexity.

## 3) Decision

Adopt this contract:
- `generateOccurrences(from:until:)` uses an exclusive upper bound: `[from, until)`.
- Business rule `RecurrenceRule.endDate` stays user-inclusive ("end on this day").
- Internally convert `endDate` to exclusive day boundary (`startOfDay(endDate) + 1 day`).

Why this is preferred:
- Matches Apple `DateInterval` behavior.
- Eliminates boundary double-counting without scattered `-1 second` hacks.
- Makes month/week window composition predictable.

## 4) Alternatives Considered

1. Keep inclusive `until` and patch callers with `-1 second`.
- Pros: low immediate churn.
- Cons: fragile and error-prone; easy to miss call sites; timezone edge risks.

2. Keep inclusive generator and add dedicated interval APIs only for charts.
- Pros: limited blast radius.
- Cons: mixed semantics in codebase; long-term confusion remains.

3. Exclusive `until` globally (chosen).
- Pros: coherent model, matches system APIs, lowest long-term maintenance cost.
- Cons: requires updating tests and some boundary assumptions now.

## 5) Scope and Impact

### Core Logic
- `Billo/Models/RecurrenceRuleGenerator.swift`
- `Billo/Models/Bill.swift`
- `Billo/Models/Income.swift`

### Boundary Call Sites to Audit
- `Billo/Features/Charts/ChartsModel.swift`
- `Billo/Utilities/BillsListSections.swift`
- `Billo/Features/BillsCalendar/Views/BillsCalendarView.swift`

### Tests to Update/Add
- `BilloTests/RecurrenceRuleTests.swift`
- `BilloTests/Features/Charts/ChartsModelTests.swift`
- `BilloTests/BillOccurrenceGenerationTests.swift`
- Any boundary-sensitive tests under `BilloTests/BillsListSectionsTests.swift`

## 6) Detailed Change Plan

### Step 1: Lock Contract in Code
- Document in function comments that `until` is exclusive.
- Ensure non-recurring checks use `< endDate` (already partly changed).
- Keep `endConditionType == .endDate` user-inclusive via internal conversion.

### Step 2: Standardize Boundary Callers
- Keep passing `monthInterval.end` from charts and monthly windows.
- Remove any ad-hoc boundary compensation where no longer needed.
- For UI code using inclusive filtering (`<= endDate`), either:
  - switch to exclusive range end and `< endExclusive`, or
  - keep current behavior intentionally with explicit comment.

### Step 3: Test Contract Migration
- Update recurring tests that currently expect inclusion when `until == occurrenceDate`.
- Replace unsafe indexed assertions with:
  - `#require(occurrences.count == N)` before indexing, or
  - single array-equality `#expect`.
- Add explicit boundary tests:
  - `until` excludes exact boundary occurrence.
  - `RecurrenceRule.endDate` still includes occurrences on that day.
  - Month trend does not double-count boundary occurrence.

### Step 4: Regression Verification
- Focused:
  - `xcodebuild -project Billo.xcodeproj -scheme Billo -destination 'platform=macOS,arch=arm64,variant=Mac Catalyst,name=My Mac' test -only-testing:BilloTests/RecurrenceRuleTests`
  - `xcodebuild -project Billo.xcodeproj -scheme Billo -destination 'platform=macOS,arch=arm64,variant=Mac Catalyst,name=My Mac' test -only-testing:BilloTests/Features/Charts/ChartsModelTests`
  - `xcodebuild -project Billo.xcodeproj -scheme Billo -destination 'platform=macOS,arch=arm64,variant=Mac Catalyst,name=My Mac' test -only-testing:BilloTests/BillOccurrenceGenerationTests`
- Then full suite.

### Step 5: Branch Hygiene
- Keep this change isolated from unrelated localization churn:
  - `Billo/Localizable.xcstrings` should be excluded from this semantic change branch unless intentionally modified.

## 7) Risks and Mitigations

Risk:
- Mixed interval assumptions causing silent off-by-one occurrence differences.

Mitigation:
- Add explicit boundary tests.
- Prefer array-equality assertions over count + indexed access.
- Audit all `generateOccurrences(...until:)` call sites before merge.

Risk:
- Calendar/timezone surprises at date boundaries.

Mitigation:
- Use UTC calendars in boundary-focused tests.
- Keep day-granularity behavior explicit in comments.

## 8) Definition of Done

- `generateOccurrences(from:until:)` behaves consistently as `[from, until)`.
- `RecurrenceRule.endDate` remains user-inclusive.
- Charts no longer double-count month-boundary occurrences.
- Boundary-sensitive tests are updated and passing.
- No unrelated file churn included in the final PR.

