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
- Build (simulator default): `xcodebuild -project Billo.xcodeproj -scheme Billo -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.1' build`
- Clean build: `xcodebuild -project Billo.xcodeproj -scheme Billo clean`
- Unit tests (default: Mac Catalyst): `xcodebuild -project Billo.xcodeproj -scheme Billo -destination 'platform=macOS,arch=arm64,variant=Mac Catalyst,name=My Mac' test`
- Unit tests (iOS Simulator): `xcodebuild -project Billo.xcodeproj -scheme Billo -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.1' test`
- Focused tests: append `-only-testing:BilloTests/<TestClass>`
- No external dependencies: Project uses only native Apple frameworks (SwiftUI, SwiftData, StoreKit 2, Charts)

## Architecture & Patterns
- **Pure SwiftUI**: No UIKit, no MVVM — follows Apple's Model-View architecture with `@Observable`, `@State`, `@Environment`.
- **Data persistence**: SwiftData with CloudKit sync for seamless iCloud backup and multi-device support.
- **Screaming Architecture**: Feature-based folders (`Features/<Feature_1>/`, `Features/<Feature_2>/`) that communicate the app's purpose at a glance.
- **Subscription system**: StoreKit 2 with `StoreKitManager` singleton for Pro feature gating across the app.
- **Data flow**: User input → @Observable model class -> SwiftData models -> automatic UI updates -> CloudKit sync.
- **Localization**: Multi-language support with localization script for generating/updating string tables. 

## Key Integration Points
- **StoreKit 2**: In-app purchases via `StoreKitManager.shared` for Pro subscription management. Product IDs: TBD
- **SwiftData + CloudKit**: Local-first data storage with automatic iCloud sync. Models defined in `Features/*/Models/`.
- **Charts Framework**: TBD
- **Design System**: Centralized `DesignSystem.swift` provides spacing, colors, typography, and reusable view modifiers.
- **Automatic Backup**: Background task exports complete app state to Documents directory with hash-based deduplication (keeps last 10 backups).

## Code Style
- Follow Swift API Design Guidelines: expressive names, argument labels that read naturally.
- Use modern Swift syntax: shortened `if let` and `guard let` (e.g., `if let lastKnownBalance` instead of `if let balance = lastKnownBalance`).
- Avoid force unwraps except in guarded test helpers; prefer `guard let` with logged failures.
- Single source of truth: Use one `@State` variable per logical concern (prefer optional types or enums over multiple boolean flags).
- File headers: Always use `//  Created by Jiri Urbasek on ...` (never Claude Code, Codex etc).
- Update localization strings for any user-facing copy changes. Follow guide at `docs/auto-translate-xcstrings.md` when manipulating with localized strings.

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
- No external dependencies — uses only native Apple frameworks.
- Universal app: Supports iPhone, iPad, and macOS via Mac Catalyst.

## Special Notes
- Do not mutate files outside the workspace root without explicit approval
- Avoid destructive git operations unless the user requests them directly
- When unsure or need to make a significant decision ASK the user for guidance

---

## Billo-Specific Context

### App Summary
**Billo** 

**Target Users**: 

### Design System
Centralized in `DesignSystem.swift`.
Always use design system constants instead of hardcoded values.
