# Agent Guide

## Purpose
Agents act as senior Swift collaborators. Keep responses concise,
clarify uncertainty before coding, and align suggestions with the rules linked below.
Explain clearly your reasoning behind your decisions and pros/cons of chosen solution.

## Rule Index
- `@ai-rules/rule-loading.md` — always load this first; it selects the right rule pack for the task.
- `@ai-rules/general.md` — baseline rules for Swift, and SwiftUI work in this codebase.
- `@ai-rules/testing.md` — testing-specific rules distilled from our TDD playbook. Required when touching tests or test fixtures.
- Deep dives live under `@docs/`, you can read it if you need longer-form architectural or product context.

## Repository Overview
- **Product**: Billo — Bill organizer app helping users not feel anxiety from missing their payment deadlines.
- **Key modules**: 
- **Architecture**: SwiftUI + SwiftData + StoreKit 2, following Screaming Architecture principles (feature-based organization).
- **Docs**: Business specification and implementation guides in `docs/`. Update when introducing new features or patterns.
- **Business Model**: Freemium (Free access with limitation, paid upgrade using In-App Subscriptions)

## Commands
- Build (simulator default): `xcodebuild -project Billo.xcodeproj -scheme Billo -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' build`
- Clean build: `xcodebuild -project Billo.xcodeproj -scheme Billo clean`
- Unit tests (default: Mac Catalyst): `xcodebuild -project Billo.xcodeproj -scheme Billo -destination 'platform=macOS,arch=arm64,variant=Mac Catalyst,name=My Mac' test`
- Unit tests (iOS Simulator): `xcodebuild -project Billo.xcodeproj -scheme Billo -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' test`
- Focused tests: append `-only-testing:BilloTests/<TestClass>`
- Screenshots run (in-memory DB pre-seeded with realistic US demo data): use the `BilloScreenshots` scheme. It launches the main app with the `Screenshots` build configuration, which sets the `SCREENSHOTS` compile condition — see `Billo/App/ScreenshotMockData.swift` and the `#if SCREENSHOTS` branches in `BilloApp.swift`.
- Onboarding run (always shows the first-launch flow): use the `BilloOnboarding` scheme. It launches the main app with the `Onboarding` build configuration (`ONBOARDING` compile condition): empty in-memory DB, CloudKit off, and the local first-launch flags (`AppPersistence`) reset on every launch — see the `#if ONBOARDING` branches in `BilloApp.swift`.
- Dependencies: native Apple frameworks (SwiftUI, SwiftData, StoreKit 2, Charts) plus a single SPM package — `simonbs/SFSymbols` 1.5.0 (SF Symbol picker UI). Adding any new dependency requires explicit user approval.

## Architecture & Patterns
- **Pure SwiftUI**: No UIKit, no MVVM — follows Apple's Model-View architecture with `@Observable`, `@State`, `@Environment`. Narrow exception: UIKit bridges are allowed only where SwiftUI has no equivalent (e.g. pre-tinted `UIImage` for colored `Menu` icons in `CategoryQuickPicker`, `UIImage(systemName:)` symbol validation in `CategoryCatalog`); keep such bridges small and isolated.
- **Data persistence**: SwiftData with CloudKit sync for seamless iCloud backup and multi-device support.
- **Screaming Architecture**: Feature-based folders (`Features/<Feature_1>/`, `Features/<Feature_2>/`) that communicate the app's purpose at a glance.
- **Subscription system**: StoreKit 2 with `StoreKitManager` singleton for Pro feature gating across the app.
- **Data flow**: User input → @Observable model class -> SwiftData models -> automatic UI updates -> CloudKit sync.
- **Localization**: Not set up yet. Strings live in `Billo/Localizable.xcstrings` (English only for now); multi-language support is planned later.

## Key Integration Points
- **PostHog Analytics**: `Billo/Shared/Analytics/` — `AnalyticsModel` (`@Observable`, injected via `.environment()`) over an `AnalyticsClient` protocol (`PostHogAnalyticsClient` in Release, `NoopAnalyticsClient` in tests/previews/SCREENSHOTS; DEBUG needs `BILLO_ENABLE_ANALYTICS=1`). Events are typed cases in `AnalyticsEvent` (names lowercase-space, property keys snake_case, categories via `CategoryIdentifier.analyticsKey` — never user text). **Monetary amounts are never tracked** (user decision — too sensitive); only non-amount dimensions like `currency_code`, `is_partial`, `days_from_due`. Screens tracked manually with `.analyticsScreen(_:)`. Data mutations capture inside `BillsModel` (services get an `analyticsCapture` closure); UI-only events capture in views. **Session replay is ON with global text masking OFF — any new view showing an amount, user-entered name/note, account ID, provider URL, or confirmation number MUST be covered by `.replayMaskSensitive()`. Granularity matters: in scrolling lists apply ONE mask on the list container, never per row — each mask injects PostHog tag UIViews whose setup re-walks the view hierarchy (profiled as the dominant cause of launch and scrolling hangs). Masked containers today: bills list ScrollView, calendar list ScrollView, DayDetailSheet list, PaymentHistoryView list; the row views inside (`BillRowView`, `PaymentRowView`, calendar rows, `CategoryCaptionLabel`) deliberately carry no masks and must only be used inside a masked container. One-off detail/edit screens keep per-view masks.** Exemption: compile-time-constant illustrative figures (e.g. mock amounts in onboarding explanation illustrations) carry no user data and deliberately stay unmasked.
- **StoreKit 2**: In-app purchases via `StoreKitManager.shared` for Pro subscription management. The product/plan lineup lives in `StoreKitManager.ProductID` — always read it from code, never assume the plan set.
- **Free-tier display caps**: `FreeTierLimits` is the single source of truth for all free-tier limit values and gate rules (never hardcode the numbers elsewhere). It gates creation AND display — over-cap items (e.g. created while Pro, then lapsed) are hidden, never deleted. `BillsModel.refresh()` is the single truncation point (`visibleBills` ranks soonest-due first, dead bills last); list, calendar, totals, notifications, and badge all derive from the visible set, and `HiddenItemsPromptRow` surfaces the overflow with a paywall CTA. Historical records (payments, frozen income snapshots) always stay visible but must not deep-link into a hidden bill's live detail (`CalendarPaymentRouting.isBillVisible`). Charts are exempt (Pro-gated, blurred teaser). New surfaces enumerating bills/incomes MUST read `billsModel.bills`/`incomes` (already capped), never fetch `Bill`/`Income` directly.
- **App Store review prompts**: `ReviewPromptModel` (`Billo/Utilities/`, env-injected from `BilloApp`) is the single decision point for `requestReview` triggers — the trigger set and thresholds live there (see `ReviewPromptTrigger`). **No manual time cooldown by design** — iOS itself caps and decides whether the dialog shows; our gates only pick quality moments. Present via `requestReview.requestAfterSettleDelay()` (cancellation-safe 1 s delay; exception: the onboarding thank-you screen calls bare `requestReview()` after its own cancellation-guarded 1 s `.task` — don't "clean that up" into the helper). Disabled in SCREENSHOTS builds. Analytics: `rating prompt requested` with a `trigger` property (`ReviewPromptTrigger` raw values).
- **SwiftData + CloudKit**: Local-first data storage with automatic iCloud sync. Models defined in `Billo/Models/` and `Features/*/Models/`.
- **Swift Charts**: Spending/income visualizations in `Features/Charts/` (cash flow, category breakdown, on-time payments, trends).
- **Design System**: Centralized `DesignSystem.swift` provides spacing, colors, typography, and reusable view modifiers.

## Code Style
- Follow Swift API Design Guidelines: expressive names, argument labels that read naturally.
- Use modern Swift syntax: shortened `if let` and `guard let` (e.g., `if let lastKnownBalance` instead of `if let balance = lastKnownBalance`).
- Avoid force unwraps except in guarded test helpers; prefer `guard let` with logged failures.
- Single source of truth: Use one `@State` variable per logical concern (prefer optional types or enums over multiple boolean flags).
- File headers: Always use `//  Created by Jiri Urbasek on ...` (never Claude Code, Codex etc).
- Keep user-facing copy extractable (use `Text`/`String(localized:)` with comments) so it lands in `Billo/Localizable.xcstrings`. No translation workflow exists yet.

## Workflow
- Ask for clarification when requirements are ambiguous; surface 2–3 options when trade-offs matter
- Update documentation and related rules when introducing new patterns or services
- Do not commit code yourself
- When creating new file, never put your name as author of the file

## Testing
- Default to TDD: create or update tests under `BilloTests/` before implementation changes.
- Use the WHEN_THEN test naming pattern and helper factories defined in the testing rule pack.
- Test only business behavior, not implementation details.
- Trigger `@ai-rules/testing.md` whenever you modify tests, fixtures, or concurrency-sensitive code paths.
- Focus on testing business logic (savings calculations, balance projections, Pro feature gating) rather than SwiftUI views.

## Environment
- Xcode 26+, Deployment target of iOS26+ and macOS26+. Simulator defaults to iPhone 17 Pro.
- External dependencies limited to the `SFSymbols` SPM package; everything else is native Apple frameworks.
- Universal app: Supports iPhone, iPad, and macOS via Mac Catalyst.

## Special Notes
- Do not mutate files outside the workspace root without explicit approval
- Avoid destructive git operations unless the user requests them directly
- When unsure or need to make a significant decision ASK the user for guidance
- Early development phase: data migrations/backfills are not required; it's acceptable to delete the app and start with freshly created data. Still warn when a change would require migration/legacy handling in a production or beta scenario.
- **macOS 26 (Tahoe) Catalyst platform bugs** (verified on macOS 26.3.1, empirically diagnosed): (1) SwiftUI sheet dismissal never reaches UIKit — the binding nils and the parent re-renders, but the presented controller stays on screen (buttons dead) until the app deactivates. Workaround: dismiss by clearing the presentation binding, then complete the teardown with a Catalyst-only UIKit sweep (`OnboardingBillSetupStepView.dismissAdjustSheet`); other sheets (`MarkPaidSheet`, `DayDetailSheet`, `BillEditView`, …) likely need the same treatment before a macOS release. (2) SwiftData `context.save()` can crash (EXC_BREAKPOINT in a `_SwiftData_SwiftUI` didSave observer, subcode 0x…3be451c4) — reproduced via `PaymentRecorder.recordPayment` on Catalyst and previously via onboarding's showcase container; iOS is unaffected. Root cause unresolved — investigate before shipping the Mac build. (3) `@Observable` environment values do not propagate into presented sheet/popover content — the first `@Environment(SomeModel.self)` read inside the presented tree traps with "No Observable object of type … found" (reproduced: MarkPaidSheet's partial-payment gate presenting the paywall). Rule: EVERY `.sheet`/`.popover` content root must re-inject the app models via `.appEnvironment(_:)` (`Shared/AppEnvironmentModels.swift`), plus any screen-scoped models (`BillModel`, `NotificationSettingsModel`) individually; views pushed inside a presented `NavigationStack` need nothing extra.

## Billo-Specific Context

### App Summary
**Billo** 

**Target Users**: 

### Design System
Centralized in `DesignSystem.swift`.
Always use design system constants instead of hardcoded values.
