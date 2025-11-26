# Billo App Architecture

## Files organization

The source code files should be organized based on features they belong to follow the principle named "Screaming Architecture" by Robert C. Martin.
E.g. `Feature/BillsList`, `Feature/BillDetail`, `Feature/Settings`, etc.

Files used among many features can be stored in `Shared` folder.

## Core app components

- SwiftUI Views
- `@Observable BillModel` - model class providing source of truth for state regarding Bills, Incomes etc. Can be shared to multiple Views using `@Environment`. Manages SwiftData data storage internally. Wraps business logic and provides it to the views.
- We do NOT want to use typical MVVM design pattern and we do NOT want to create ViewModels for each screen. Instead reuse `@Observable BillsModel` between many screens.
- SwiftData storage - synced via iCloud.


