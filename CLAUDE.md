# 📱 Savemo – Business Specification

Type: Universal App for iOS, iPadOS, macOS
Business Model: Freemium (Core Features Free + In-App Purchases for Premium Features)

## 🧩 App Summary

**Savemo** is a personal finance app that helps users calculate how much they need to save monthly to afford future expenses. The app allows users to create multiple savings accounts, add one-time or recurring future events (expenses), and calculates how much should be saved each month to stay on track. It is designed for people who prefer a proactive, low-maintenance approach to money management.

---

## 🎯 Core Features

### 🔐 Free Tier
- Create up to **2 savings accounts**
- Add **future events** (one-time expenses)
- Automatic **monthly saving amount** calculation based on:
  - Account balance
  - Future event due dates and amounts
- **Rounded vs. exact** saving toggle
- **Balance projection chart**
- Data stored **locally** and synced via **iCloud**
- **PDF Export** with watermark

---

### 💎 Pro Tier (via In-App Purchase)
- **Unlimited savings accounts**
- **Recurring events** (e.g., rent, subscriptions, annual bills)
- **Custom Account Currency**
- **Advanced Data Export** (CSV, XLSX)
- **PDF Export without watermark**
- Unlocks **lifetime** or **subscription-based** access:
  - $0.99/month
  - $9.99/year
  - $14.99 one-time (lifetime)

---

## 🧩 Key Features

### 🟩 Core (Free) Features

1. Account Management
- Users can create and name up to 2 savings accounts
- Each account includes:
- Custom title
- Initial balance (optional)
- A list of upcoming financial events

2. Expense events Tracking
- Add/edit/delete events
- Each event includes:
- Name (optional)
- Target date
- Estimated amount

3. Monthly Savings Calculation
- Calculates monthly savings needed to fund all listed events
- Users can choose from:
- Rounded values (to decimals / tenths / hundreds / thousands)
- Two possible trategies of monthly savings:
  a) Even monthly savings - always same value for all expenses over all time  
  b) Different monthly savings - different value each month, computed only safe for nearest future expense event

4. Balance Projection Chart
- Interactive line graph showing:
- Monthly savings growth
- Balance drops when events occur
- Time-axis and value-axis labeled clearly

5. Sync & Offline
- App data stored locally using SwiftData and automatically synced via iCloud.

6. Automatic Data Backup
- Automatic backup of all app data when app goes to background
- Hash-based deduplication prevents redundant backups when data unchanged
- Complete data export saved to Documents directory with timestamps  
- Self-managing cleanup (keeps last 10 backups)

7. Feedback Mechanism
- In-app feature for users to send suggestions or bug reports

---

💎 Premium Features (Pro Upgrade)

1. Unlimited Accounts
- Remove the 2-account restriction
- Ideal for users managing multiple categories (e.g., Travel, Home, Car, Kids, Subscriptions)

2. Recurring Events
- Add repeatable expenses (e.g., insurance, subscriptions)
- Define frequency: monthly, quarterly, yearly

3. Custom Account Currency
- Set a custom currency for each savings account, independent of the device's locale.

4. Advanced Data Export
- Export account history and events as .CSV or .XLSX.
- Export individual account reports as a PDF **without a watermark**.
- Email or save to Files.

## 📱 Core Screens

### 🏠 Home (Account List)
- List of accounts
  - Allow custom sorting using long-press gesture with drag handlers indicators
  - Swipe-to-delete
  - Shows total monthly saving required (aggregated) at the very bottom of the table

- Add new account
  - Uses default currency value based device locale 

### 📂 Account Detail
- Account name & balance
- Monthly saving required + tags for chosen configuration (rounded, even / nearest expense)
- List of upcoming events
- Button: Add Event
- Chart: balance over time
- Optional: display recurring event badges

### ➕ Add/Edit Event
- Label
- Amount
- Date picker
- Toggle for recurring
- Frequency selector (if recurring)

### ⚙️ Settings
- Export data
- Restore purchases
- Manage subscription (link to App Store)
- App version, privacy policy, etc.

---

## 🧠 Subscription Strategy

| Tier      | Price      | Includes                                        |
|-----------|------------|-------------------------------------------------|
| Free      | $0         | 2 accounts, basic events, iCloud sync, watermarked PDF export |
| Monthly   | $0.99/mo   | Unlimited accounts, recurring events, custom currency, advanced export |
| Yearly    | $9.99/yr   | Same as monthly (2 months free)                 |
| Lifetime  | $14.99     | All Pro features forever                        |

---

## 🚀 Monetization Setup

**Product IDs (StoreKit 2):**
- `com.savemo.pro.monthly`
- `com.savemo.pro.yearly`
- `com.savemo.pro.lifetime`

**StoreKit Configuration File** will be used for local testing.

---

## 🔐 Technology & Architecture

- **SwiftUI + StoreKit 2 + SwiftData**
- Follows **Model–View** architecture (no MVVM)
- Uses **CloudKit** for syncing
- State management via `@Observable`, `@State`, `@Environment`
- Charts using Apple's `Charts` framework

---

## 🧠 Target Users

- People planning for **future expenses** (e.g., vacations, car repairs)
- Users who **don't want full budgeting apps**
- Financially aware individuals who want **a buffer** or **forecasting tool**
- Users who prefer **no-login**, **local-first** privacy-respecting apps

---

## 🔍 App Store Optimization (ASO)

- **App Name**: Savemo
- **Subtitle**: "Know what to save each month"
- **Keywords**: savings, tracker, planner, monthly, budget, goals, finance, money
- **Tagline**: "Never wonder how much to save again"

---

## 🔜 Optional Future Features
(Not in initial release)
- Monthly savings reminders/notifications
- Notifications when savings fall behind
- Smart suggestions (e.g., split large expenses automatically)
- Widgets for balance or monthly goals
- Siri Shortcuts or voice query: "Hey Siri, how much do I need to save this month?"

---

# General Architectural Principles of the development

Write idiomatic SwiftUI code following Apple's latest architectural recommendations and best practices.

## Core Philosophy

- SwiftUI is the default UI paradigm for Apple platforms - embrace its declarative nature
- Avoid legacy UIKit patterns and unnecessary abstractions
- Focus on simplicity, clarity, and native data flow
- Let SwiftUI handle the complexity - don't fight the framework

## Architecture Guidelines

### 1. Embrace Native State Management

Use SwiftUI's built-in property wrappers appropriately:
- `@State` - Local, ephemeral view state
- `@Binding` - Two-way data flow between views
- `@Observable` - Shared state (iOS 17+)
- `@ObservableObject` - Legacy shared state (pre-iOS 17)
- `@Environment` - Dependency injection for app-wide concerns

### 2. State Ownership Principles

- Views own their local state unless sharing is required
- State flows down, actions flow up
- Keep state as close to where it's used as possible
- Extract shared state only when multiple views need it

### 3. Modern Async Patterns

- Use `async/await` as the default for asynchronous operations
- Leverage `.task` modifier for lifecycle-aware async work
- Avoid Combine unless absolutely necessary
- Handle errors gracefully with try/catch

### 4. View Composition

- Build UI with small, focused views
- Extract reusable components naturally
- Use view modifiers to encapsulate common styling
- Prefer composition over inheritance

### 5. Code Organization

- Organize by feature, not by type (avoid Views/, Models/, ViewModels/ folders)
- Keep related code together in the same file when appropriate
- Use extensions to organize large files
- Follow Swift naming conventions consistently

### 6. Modern Swift Syntax

- Use shortened `if let` and `guard let` syntax (Swift 5.7+):
  - ✅ `if let lastKnownBalance` instead of `if let lastBalance = lastKnownBalance`
  - ✅ `guard let self else` instead of `guard let self = self else`
- Prefer concise, readable syntax over verbose equivalents

### 7. File Headers

- **NEVER** write `//  Created by Claude Code on ...` in file headers
- **ALWAYS** use `//  Created by Jiri Urbasek on ...` when creating new files
- Follow the existing project's file header format and attribution

## Implementation Patterns

### Simple State Example
```swift
struct CounterView: View {
    @State private var count = 0
    
    var body: some View {
        VStack {
            Text("Count: \(count)")
            Button("Increment") { 
                count += 1 
            }
        }
    }
}
```

### Shared State with @Observable
```swift
@Observable
class UserSession {
    var isAuthenticated = false
    var currentUser: User?
    
    func signIn(user: User) {
        currentUser = user
        isAuthenticated = true
    }
}

struct MyApp: App {
    @State private var session = UserSession()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
        }
    }
}
```

## Best Practices

### DO:
- Write self-contained views when possible
- Use property wrappers as intended by Apple
- Test logic in isolation, preview UI visually
- Handle loading and error states explicitly
- Keep views focused on presentation
- Use Swift's type system for safety

### DON'T:
- Create ViewModels for every view
- Move state out of views unnecessarily
- Add abstraction layers without clear benefit
- Use Combine for simple async operations
- Fight SwiftUI's update mechanism
- Overcomplicate simple features

### Avoid Redundant State Variables:
Never use multiple @State variables to accomplish a single logical task. This creates opportunities for inconsistent state and bugs.

**❌ Wrong - Multiple variables for single concern:**
```swift
@State private var shouldDisplayError: Bool = false
@State private var errorMessage: String = ""

@State private var shouldDismissOnErrorOK: Bool = false  
@State private var errorText: String?
```

**✅ Good - Single source of truth:**
```swift
// Simple optional for presence + data
@State private var errorMessage: String?

// Complex behavior encoded in enum
enum DisplayedError {
    case staying(String)    // Shows error, keeps user on screen
    case closing(String)    // Shows error, closes screen on "OK"
    
    var message: String {
        switch self {
        case .staying(let message), .closing(let message):
            return message
        }
    }
}
@State private var displayedError: DisplayedError?
```

**Usage patterns:**
```swift
// Simple popup/alert
.alert("Error", isPresented: $errorMessage.isPresent()) {
    Button("OK") {
        errorMessage = nil
    }
} message: {
    if let errorMessage = errorMessage {
        Text(errorMessage)
    }
}

// Complex contextual behavior  
.alert("Error", isPresented: $displayedError.isPresent()) {
    Button("OK") {
        if case .closing = displayedError {
            dismiss()
        }
        displayedError = nil
    }
} message: {
    if let displayedError = displayedError {
        Text(displayedError.message)
    }
}
```

**Benefits:**
- Single source of truth prevents state inconsistencies
- Optional types naturally encode presence/absence
- Enums encode complex behavior in the type system
- Impossible to have contradictory state combinations

## Testing Strategy

- Unit test business logic and data transformations
- Use SwiftUI Previews for visual testing
- Test @Observable classes independently
- Keep tests simple and focused
- Don't sacrifice code clarity for testability

## Modern Swift Features

- Use Swift Concurrency (async/await, actors)
- Leverage Swift 6 data race safety when available
- Utilize property wrappers effectively
- Embrace value types where appropriate
- Use protocols for abstraction, not just for testing

## Summary

Write SwiftUI code that looks and feels like SwiftUI. The framework has matured significantly - trust its patterns and tools. Focus on solving user problems rather than implementing architectural patterns from other platforms.

---

# Savemo project specific implementation guides

## Design System Usage for Savemo App:

- Always use the updated DesignSystem with descriptive names (not abbreviations)
- Spacing: use .extraSmall, .small, .medium, .large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge
- BorderRadius: use .small, .medium, .large, .extraLarge, .extraExtraLarge, .full
- Colors: use adaptive colors like .neutralWhite, .neutralBlack, .neutralLightGray, .primaryBlue, etc.
- Typography: use predefined font styles like .largeTitle, .title3, .headline, .body, .caption, etc.
- View modifiers: use .cardStyle(), .actionCardStyle(), PrimaryButtonStyle(), SecondaryButtonStyle()
- The app supports dark mode automatically through adaptive colors
- Always follow this design system when creating new screens or UI elements


## Use Screaming Architecture (by Uncle Bob) for organizing files in the project

> "Your architecture should scream the business it serves."  
> — Robert C. Martin, Clean Architecture

### 🧩 Core Ideas

- ✅ **Architecture should communicate the system's purpose**  
  → When you look at the structure, folder names, and modules, it should be obvious what the app *does*, not how it works technically.

- ❌ Avoid architectures that scream "Rails", "Spring", or "MVVM"  
  → These say more about the framework or patterns than the *domain*.

- 📦 Prefer business/domain-oriented folders like:
  - `Orders/`
  - `Payments/`
  - `Scheduling/`
  - over technical ones like:
  - `Controllers/`
  - `Services/`
  - `Models/`

- 🧠 Focus on **Use Cases and Core Behaviors**  
  → Code organization should reflect what the app *does for the user*, not the tech stack or layers.

- 🕸 Layer the system from the **domain inward out**, not UI downward in  
  → Frameworks, databases, and tools should be details — not the backbone of your architecture.

- 🏛 Use **Clean Architecture principles**  
  → Entities and use cases live at the center. Frameworks and delivery mechanisms are outer, interchangeable layers.

### 🔁 Summary

- Architecture should scream the **business logic**, not the **frameworks**
- Organize by **features/use cases**, not **technical roles**
- Keep frameworks and tools **at the edges** of your architecture
- Domain logic should be **central, independent, and testable**


## 🧱 Data Model

### `Account`
- `name: String`
- `createdDate: Date`
- `currency: String`
- `sortOrder: Int`
- `balances: [Balance]` (relationship to `Balance` entries)
- `expenses: [Expense]` (relationship to `Expense`)

### `Balance`
- `date: Date`
- `amount: Decimal`
- `type: BalanceType` (enum: `.userEntered`)
- `account: Account?` (relationship back to `Account`)

### `Expense`
- `label: String`
- `amount: Decimal`
- `dueDate: Date`
- `createdDate: Date`
- `account: Account?` (relationship back to `Account`)

(optionally in the future)
- `isRecurring: Bool`
- `recurrenceFrequency: Recurrence?` (optional enum)

---

## 💰 Balance & Savings Calculation Logic

### Balance History System
The app maintains a complete history of balance entries for each account, allowing users to track their account balance over time and providing more accurate savings calculations.

### Current Balance Calculation
The **current balance** is computed by projecting from the last known balance entry:
```
currentBalance = lastKnownBalance.amount + (monthsSinceLastBalance × monthlySavingsNeeded)
```

Where:
- `lastKnownBalance` = Most recent user-entered balance entry
- `monthsSinceLastBalance` = Number of complete months between last balance date and today
- `monthlySavingsNeeded` = Monthly amount needed to fund all upcoming expenses

### Monthly Savings Calculation
The **monthly savings needed** is calculated from the last balance date (not current date):
```
monthlySavingsNeeded = totalExpenseAmount ÷ monthsFromLastBalanceToExpenses
```

This approach provides several benefits:
1. **Accurate projections**: Uses actual balance checkpoints rather than estimates
2. **Flexible timing**: Users can update balance anytime, calculations adjust automatically  
3. **Historical tracking**: Complete audit trail of balance changes over time
4. **Realistic planning**: Accounts for actual time available to save (from last balance entry)

### Balance Management
- Users can add new balance entries anytime via "Edit Balance" in account detail
- Each balance entry includes date, amount, and type (currently only `.userEntered`)
- Users can view and delete balance history (minimum one entry required)
- Balance entries are sorted chronologically with most recent marked as "Current"
- Future savings calculations always start from the most recent balance entry date

---

# 💳 Paywall & Pro Features Implementation

## Overview
The app includes a complete paywall system for upgrading users to Pro features using StoreKit 2. The implementation is designed to be reusable throughout the app wherever Pro features need to be unlocked.

## Components

### 1. StoreKitManager
**File**: `Features/Subscription/StoreKitManager.swift`
- `@Observable` class for managing subscription state
- Handles purchase flow, transaction verification, and subscription status
- Provides `isPro` property to check Pro status anywhere in the app
- Uses Product IDs: `com.savemo.pro.monthly`, `com.savemo.pro.yearly`, `com.savemo.pro.lifetime`

### 2. PaywallView  
**File**: `Features/Subscription/PaywallView.swift`
- Modern, clean paywall UI following the app's design system
- Shows Pro features, Free vs Pro comparison, and pricing options
- Accepts `onPurchaseSuccess` callback for custom post-purchase actions
- Includes 7-day free trial for subscriptions

## Usage Examples

### Basic Paywall Display
```swift
.sheet(isPresented: $showingPaywall) {
    PaywallView(onPurchaseSuccess: {
        // Optional: Custom action after successful purchase
        showingAddAccount = true
    })
}
```

### Feature Gating with Pro Check
```swift
@State private var storeKitManager = StoreKitManager.shared
@State private var showingPaywall = false

Button("Add Recurring Event") {
    if storeKitManager.isPro {
        // Show recurring event creation
        showingAddRecurringEvent = true
    } else {
        // Show paywall to unlock feature
        showingPaywall = true
    }
}
```

### Conditional UI Based on Pro Status
```swift
if storeKitManager.isPro {
    // Show Pro features
    RecurringEventsSection()
    ExportDataButton()
    iCloudSyncToggle()
} else {
    // Show upgrade prompts or disabled states
    UpgradePromptCard(feature: "Recurring Events")
}
```

## Pro Features to Gate

### Core Pro Features
1. **Unlimited Accounts** - Block creation of 3rd+ accounts
2. **Recurring Events** - Disable recurring expense creation
3. **Custom Account Currency** - Disable currency picker in account settings
4. **Data Export** - Disable CSV/XLSX export options and enable watermarks on PDF exports.

### Implementation Locations
- **Account Creation**: `AccountListView.handleAddAccount()`
- **Recurring Events**: Add checks in `ExpenseDetailView`
- **Custom Currency**: Add checks in `EditAccountView`
- **Settings Screen**: Gate export options in `ExportAllDataView`
- **Data Export**: Add Pro checks before export functions and for PDF watermarking.

## Testing with StoreKit Configuration

### Local Testing Setup
1. **StoreKit Configuration File**: `Savemo.storekit` 
2. **Configure in Xcode**: Scheme → Run → Options → StoreKit Configuration
3. **Reset Test State**: Debug → StoreKit → Manage Transactions → Delete All

### Test Scenarios
- Purchase monthly/yearly/lifetime subscriptions
- Test restore purchases functionality
- Verify Pro status updates immediately
- Test paywall-to-feature flow (e.g., add account after purchase)

## Design Guidelines

### Paywall UI Structure
```
Gray Background
├── Header (Star + Title + Description) - No card
├── "Pro Features" title - On gray background
│   └── Feature list - In card
├── "Free vs. Pro" title - On gray background  
│   └── Comparison table - In card
├── "Choose Your Plan" title - On gray background
│   └── Pricing options - In card
├── Primary button + Restore button - On gray background
└── Legal text - On gray background
```

### Feature Gating Best Practices
1. **Graceful Degradation**: Show what's possible, indicate what requires Pro
2. **Clear Value Prop**: Explain why the feature needs Pro
3. **Seamless Flow**: After purchase, immediately enable the requested feature
4. **Consistent Messaging**: Use same Pro feature descriptions across the app

## StoreKit Products Configuration

### Product Identifiers
- **Monthly**: `com.savemo.pro.monthly` - $0.99/month with 7-day free trial
- **Yearly**: `com.savemo.pro.yearly` - $9.99/year with 7-day free trial (Best Value)
- **Lifetime**: `com.savemo.pro.lifetime` - $14.99 one-time purchase

### Subscription Group
- **Group ID**: `21485495`
- **Name**: "Savemo Pro"
- All subscriptions in same group (monthly/yearly)

---

## Unit Testing Best Practices

See [Unit Testing Best Practices](./docs/unit-testing-best-practices.md)

## Development Memories

- Always use iPhone 16 as a destination for xcodebuild commands

## VibeTunnel Terminal Title Management

When working in VibeTunnel sessions, actively use the `vt title` command to communicate your current actions and progress:

### Usage
vt title "Current action - project context"

### Guidelines
- **Update frequently**: Set the title whenever you start a new task, change focus, or make significant progress
- **Be descriptive**: Use the title to explain what you're currently doing (e.g., "Analyzing test failures", "Refactoring auth module", "Writing documentation")
- **Include context**: Add PR numbers, file names, or feature names when relevant
- **Think of it as a status indicator**: The title helps users understand what you're working on at a glance
- If `vt` command fails (only works inside VibeTunnel), simply ignore the error and continue

### Examples
#### When starting a task
vt title "Setting up Git app integration"

#### When debugging
vt title "Debugging CI failures - playwright tests"

#### When working on a PR
vt title "Implementing unique session names - github.com/amantus-ai/vibetunnel/pull/456"

#### When analyzing code
vt title "Analyzing session-manager.ts for race conditions"

#### When writing tests
vt title "Adding tests for GitAppLauncher"

### When to Update
- At the start of each new task or subtask
- When switching between different files or modules
- When changing from coding to testing/debugging
- When waiting for long-running operations (builds, tests)
- Whenever the user might wonder "what is Claude doing right now?"

This helps users track your progress across multiple VibeTunnel sessions and understand your current focus.