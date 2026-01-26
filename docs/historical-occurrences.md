# Historical Occurrences & Payments (Current Implementation)

## Decision Summary
- **Model choice:** IssuedOccurrence + PaymentEntry (Option A).
- **Issuance timing:** **User-action only** (bill edit, payment, delete payment). No background tasks.
- **Future occurrences:** **Not pre-generated**; generated on the fly for UI.
- **Partial payments:** Supported via multiple PaymentEntry records per IssuedOccurrence.
- **CloudKit:** No `.unique` attributes; uniqueness enforced in app logic.
- **UI date display:** Always show dates in the **user's local timezone**.

## Data Models

### Bill
**Stored properties**
- `stableID: String` (UUID string; used for cross-device identity)
- `name: String`
- `amount: Decimal`
- `currencyCode: String`
- `dueDate: Date`
- `notes: String?`
- `accountIdentifier: String?`
- `providerURL: String?`
- `categoryIdentifierRawValue: String?`
- `createdDate: Date`
- `lastUpdatedDate: Date`
- `recurrenceRule: RecurrenceRule?`
- `issuedOccurrences: [IssuedOccurrence]?` (relationship, optional for CloudKit)

**Derived helpers**
- `occurrenceKey(for: Date)` -> `stableID:YYYY-MM-DD` **UTC date only**
- `issuedOccurrence(for: Date)`
- `paymentEntries(for: Date)`
- `totalPaid / isFullyPaid / remainingBalance`

### IssuedOccurrence
**Stored properties**
- `occurrenceKey: String` (app-logic unique; no `.unique` attribute)
- `dueDate: Date`
- **Snapshot fields** (immutable after creation)
  - `billName: String`
  - `billAmount: Decimal`
  - `billCurrencyCode: String`
  - `billAccountIdentifier: String?`
  - `billNotes: String?`
  - `billCategoryRawValue: String?`
- `createdDate: Date`
- `bill: Bill?` (optional relationship)
- `paymentEntries: [PaymentEntry]?` (optional relationship)

### PaymentEntry
**Stored properties**
- `amount: Decimal`
- `datePaid: Date`
- `confirmationNumber: String?`
- `notes: String?`
- `createdDate: Date`
- `issuedOccurrence: IssuedOccurrence?` (only relationship)

**Derived helpers**
- `occurrenceDate` -> `issuedOccurrence.dueDate` (fallback to `datePaid` if missing)
- `snapshotName / snapshotAmount / snapshotCurrencyCode / snapshotAccountIdentifier / snapshotNotes / snapshotCategoryIdentifier` -> from IssuedOccurrence
- `bill` -> `issuedOccurrence.bill`

## Relationships (CloudKit-Safe)
- `Bill (1) -> IssuedOccurrence (0..*)` (optional array, deleteRule: `.nullify`)
- `IssuedOccurrence (1) -> PaymentEntry (0..*)` (optional array, deleteRule: `.cascade`)
- `PaymentEntry (0..1) -> IssuedOccurrence` (optional, deleteRule: `.nullify`)

> **Note:** Deleting a Bill **preserves** its IssuedOccurrences and PaymentEntries for historical records. The `bill` reference on orphaned IssuedOccurrences will be `nil`. PaymentEntry still cascades from IssuedOccurrence since individual payment records have no meaning without their occurrence snapshot.

## Occurrence Key Strategy (Option A)
- Format: `stableID:YYYY-MM-DD` (UTC date components only).
- Avoids timezone/DST drift when identifying the same occurrence across devices.
- UI **still displays dates in user's timezone**.

## Lifecycle Rules (User-Action Only)

### 1) Bill Edit (Primary Issuance Trigger)
**Goal:** preserve past-due history without background tasks.
- Capture `BillSnapshot` **before** applying edits.
- For each **past-due** occurrence without an IssuedOccurrence:
  - Build `occurrenceKey`.
  - If no IssuedOccurrence exists -> **create one using pre-edit values**.
- Future occurrences remain live and editable.

### 2) Mark Paid / Record Payment
- Ensure IssuedOccurrence exists for that due date:
  - If missing -> create using current Bill values.
- Create **PaymentEntry** linked to the IssuedOccurrence.
- Cancel notifications for that occurrence.

### 3) Delete Payment Entry
- **Always use `BillsModel.deletePaymentEntry(_:)`** to ensure notifications and badge are refreshed.
- Delete the PaymentEntry.
- If **no remaining payments** for that IssuedOccurrence **and due date is in the future** -> delete the IssuedOccurrence.
- If due date is **today or past** -> keep IssuedOccurrence (historical snapshot).
- Refresh sections and notifications after deletion.

> **Important:** Do NOT use `modelContext.delete(payment)` directly in views. This bypasses notification/badge refresh and leaves the app in an inconsistent state.

## Partial Payments
- Multiple PaymentEntry records can exist for the same IssuedOccurrence.
- `totalPaid` = sum of entries.
- `isFullyPaid` when `totalPaid >= expectedAmount`.

## CloudKit Sync Safety
- **No `.unique` attributes** (avoids CloudKit conflicts).
- **Idempotent creation:** always check by `occurrenceKey` before insert.
- **No background issuance:** no app-launch or timer mutations.
- **Duplicates:** still possible if two devices create the same occurrence before sync; app logic should treat IssuedOccurrence as immutable and prefer the first.

## UI Behavior
- **Future occurrences:** generated on the fly from Bill recurrence.
- **Past occurrences:** use IssuedOccurrence snapshots when available.
- **Date display:** always use the user's local timezone.
