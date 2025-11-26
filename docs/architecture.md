# Billo App Architecture

Billo is bill tracking app for iOS, iPadOS and macOS. Written in Swift and SwiftUI.

## Minimum deployment targets

iOS 26+
macOS 26+

## Core app components

- SwiftUI Views
- `@Observable BillModel` - model class providing source of truth state about Bills, Incomes etc. Can be shared to multiple Views using `@Environment`. Manages SwiftData data storage internally.
- SwiftData storage - synced via iCloud.


