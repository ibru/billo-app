# Horizontal Paging Between BillsListView and BillsCalendarView

## Goal
Enable horizontal swipe paging between `BillsListView` and `BillsCalendarView` in `BillsHomeSwitchView`, while preserving swipe-to-action functionality on bill rows (e.g., "Mark Paid").

## The Problem

### Gesture Conflict
When using horizontal paging (via `TabView` with `.tabViewStyle(.page)` or `ScrollView` with `.scrollTargetBehavior(.paging)`), there's a fundamental conflict with horizontal swipe gestures on row items:

1. **Parent wins by default**: SwiftUI's gesture system is hierarchical - the outer horizontal ScrollView/TabView captures horizontal swipes before child gestures can claim them.

2. **`.swipeActions` cannot be prioritized**: The `List` modifier `.swipeActions` uses UIKit's internal gesture recognizers. There's no SwiftUI API to give these gestures priority over a parent container's gestures.

3. **Structure doesn't matter**: Whether using `List` or `ScrollView + LazyVStack` for the inner content, the outer paging gesture still wins.

### What Was Tried

```swift
// Attempted: ScrollView with paging behavior
ScrollView(.horizontal) {
    LazyHStack(spacing: 0) {
        ForEach(BillsHomeViewMode.allCases) { mode in
            // BillsListView or BillsCalendarView
        }
        .containerRelativeFrame(.horizontal)
    }
    .scrollTargetLayout()
}
.scrollTargetBehavior(.paging)
.scrollPosition(id: $scrollPosition)
```

**Result**: Paging works, but swipe actions on rows don't - the entire screen swipes instead.

## The Solution

### Custom Swipe-to-Action with `.highPriorityGesture()`

The only way to give row swipes precedence over parent paging is to use custom `DragGesture` with `.highPriorityGesture()`:

```swift
struct SwipeToActionRow<Content: View, ActionContent: View>: View {
    let content: Content
    let actionContent: ActionContent
    let actionWidth: CGFloat
    let onAction: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isRevealed = false

    init(
        actionWidth: CGFloat = 80,
        onAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content,
        @ViewBuilder action: () -> ActionContent
    ) {
        self.actionWidth = actionWidth
        self.onAction = onAction
        self.content = content()
        self.actionContent = action()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Action button revealed on swipe
            actionContent
                .frame(width: actionWidth)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        offset = 0
                        isRevealed = false
                    }
                    onAction()
                }

            // Main content
            content
                .offset(x: offset)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            let translation = value.translation.width
                            // Only allow left swipe (negative values)
                            if translation < 0 {
                                offset = max(translation, -actionWidth)
                            } else if isRevealed {
                                offset = min(0, -actionWidth + translation)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.3)) {
                                // Snap to revealed or hidden
                                if value.translation.width < -actionWidth / 2 ||
                                   value.predictedEndTranslation.width < -actionWidth {
                                    offset = -actionWidth
                                    isRevealed = true
                                } else {
                                    offset = 0
                                    isRevealed = false
                                }
                            }
                        }
                )
        }
        .clipped()
    }
}
```

### Key: `.highPriorityGesture()`

The critical piece is `.highPriorityGesture()` instead of `.gesture()`:

```swift
.highPriorityGesture(
    DragGesture(minimumDistance: 10)
        // ...
)
```

This tells SwiftUI: "This gesture should be recognized before any parent gestures."

### Implementation Steps

1. **Create `SwipeToActionRow` component** in `Billo/Components/` or similar location

2. **Replace `.swipeActions` in `BillsListView`**:
   ```swift
   // Before (doesn't work with paging)
   ForEach(occurrences) { occurrence in
       BillRowView(occurrence: occurrence)
           .swipeActions(edge: .trailing) {
               Button { markPaid(occurrence) } label: {
                   Label("Mark Paid", systemImage: "checkmark.circle")
               }
           }
   }

   // After (works with paging)
   ForEach(occurrences) { occurrence in
       SwipeToActionRow(onAction: { markPaid(occurrence) }) {
           BillRowView(occurrence: occurrence)
       } action: {
           Label("Mark Paid", systemImage: "checkmark.circle")
               .foregroundStyle(.white)
               .frame(maxHeight: .infinity)
               .background(.green)
       }
   }
   ```

3. **Refactor `BillsListView` from `List` to `ScrollView + LazyVStack`**:
   - `List` with `.swipeActions` won't work
   - Custom swipe gestures require manual row layout
   - This also enables consistent styling with `BillsCalendarView`

4. **Update `BillsHomeSwitchView`** with horizontal paging:
   ```swift
   ScrollView(.horizontal) {
       LazyHStack(spacing: 0) {
           ForEach(BillsHomeViewMode.allCases) { mode in
               // views...
               .containerRelativeFrame(.horizontal)
               .id(mode)
           }
       }
       .scrollTargetLayout()
   }
   .scrollTargetBehavior(.paging)
   .scrollPosition(id: $scrollPosition)
   ```

5. **Add bidirectional sync** between `scrollPosition` and `@AppStorage`:
   ```swift
   .onChange(of: scrollPosition) { _, newValue in
       if let newValue {
           viewModeRawValue = newValue.rawValue
       }
   }
   .onChange(of: viewModeRawValue) { _, _ in
       scrollPosition = currentViewMode
   }
   .onAppear {
       scrollPosition = currentViewMode
   }
   ```

## Files to Modify

1. **New**: `Billo/Components/SwipeToActionRow.swift` - Reusable swipe component
2. **Modify**: `Billo/Features/BillsList/BillsListView.swift` - Replace List with ScrollView, use SwipeToActionRow
3. **Modify**: `Billo/Features/BillsHome/BillsHomeSwitchView.swift` - Add horizontal paging ScrollView
4. **Optional**: `Billo/Features/BillsCalendar/Views/BillsCalendarView.swift` - Add swipe actions to calendar rows if desired

## Considerations

### Pros
- Native SwiftUI solution (no UIKit wrappers)
- Full control over swipe behavior and animations
- Consistent gesture handling across both views
- Works with iOS 17+ paging APIs

### Cons
- Loses some `List` features (automatic separators, selection styles)
- More code to maintain than `.swipeActions`
- Need to handle edge cases (multiple rows revealed, etc.)

### Edge Cases to Handle
- Only one row should be revealed at a time (close others when opening new)
- Reset revealed state when scrolling away
- Handle full-swipe-to-trigger action (optional)
- Accessibility: ensure VoiceOver can still trigger actions

## Alternative Approaches Considered

1. **TabView with `.tabViewStyle(.page)`**: Same gesture conflict, uses UIPageViewController internally
2. **Conditional `.scrollDisabled()`**: Would break paging entirely
3. **UIKit wrapper (UIPageViewController)**: Violates pure SwiftUI constraint, complex gesture delegate setup
4. **Disable paging, use picker only**: Works but loses discoverability of swipe navigation

## References

- SwiftUI Gesture Priority: `highPriorityGesture()`, `simultaneousGesture()`
- iOS 17+ Paging: `scrollTargetBehavior(.paging)`, `containerRelativeFrame()`
- Related files: `BillsHomeSwitchView.swift:24-33`, `BillsListView.swift:90-97`
