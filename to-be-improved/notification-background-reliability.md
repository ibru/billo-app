# Notification Background Reliability Improvements

**Status:** Deferred for v1
**Priority:** Implement if user feedback indicates reliability issues
**Related:** `tmp/notifications-plan.md`

---

## Problem Statement

iOS restricts background execution. In v1, we rely on:
1. Full refresh on every app foreground
2. Immediate updates on user actions (markPaid, delete, etc.)
3. 90-day pre-scheduled notification horizon

**Limitations of v1 approach:**
- Badge becomes stale if user doesn't open the app for extended periods
- New recurring bill occurrences aren't scheduled until app opens
- If user pays a bill outside the app (via bank), notification still fires

---

## Proposed Solution: Background Tasks

Add two iOS background task types to periodically refresh notifications:

### Layer 1: BGAppRefreshTask
- iOS grants ~30 seconds periodically (timing controlled by iOS)
- Lightweight refresh of notifications and badge
- Not guaranteed to run, but increases accuracy

### Layer 2: BGProcessingTask
- Longer execution when device is charging and idle
- Deep refresh of all notifications
- More reliable than BGAppRefreshTask

---

## Implementation

### 1. Info.plist Additions

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.billo.refresh</string>
    <string>com.billo.processing</string>
</array>

<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
</array>
```

### 2. BackgroundRefreshScheduling Protocol

Add to existing protocols:

```swift
protocol BackgroundRefreshScheduling: Sendable {
    /// Schedules background app refresh task
    func scheduleAppRefresh() throws

    /// Schedules background processing task (runs when charging)
    func scheduleProcessingTask() throws

    /// Handles background refresh execution
    func handleAppRefresh(
        task: BGAppRefreshTask,
        modelContainer: ModelContainer
    ) async

    /// Handles background processing execution
    func handleProcessingTask(
        task: BGProcessingTask,
        modelContainer: ModelContainer
    ) async
}
```

### 3. BackgroundRefreshManager Implementation

```swift
import BackgroundTasks
import SwiftData

final class BackgroundRefreshManager: BackgroundRefreshScheduling {
    static let appRefreshIdentifier = "com.billo.refresh"
    static let processingIdentifier = "com.billo.processing"

    private let notificationCoordinator: NotificationCoordinating

    init(notificationCoordinator: NotificationCoordinating) {
        self.notificationCoordinator = notificationCoordinator
    }

    // MARK: - Registration (call from BilloApp.init)

    func registerTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.appRefreshIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self else {
                task.setTaskCompleted(success: false)
                return
            }
            Task {
                await self.handleAppRefresh(task: task as! BGAppRefreshTask)
            }
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.processingIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self else {
                task.setTaskCompleted(success: false)
                return
            }
            Task {
                await self.handleProcessingTask(task: task as! BGProcessingTask)
            }
        }
    }

    // MARK: - Scheduling

    func scheduleAppRefresh() throws {
        let request = BGAppRefreshTaskRequest(identifier: Self.appRefreshIdentifier)
        // Schedule for 1 hour from now (iOS decides actual time)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
        try BGTaskScheduler.shared.submit(request)
    }

    func scheduleProcessingTask() throws {
        let request = BGProcessingTaskRequest(identifier: Self.processingIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false  // Will run on battery but prefers charging
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 3600)  // 4 hours
        try BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Task Handlers

    func handleAppRefresh(
        task: BGAppRefreshTask,
        modelContainer: ModelContainer
    ) async {
        // Schedule next refresh first (in case we get terminated)
        try? scheduleAppRefresh()

        // Set up expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Bill>()

        do {
            let bills = try context.fetch(descriptor)
            try await notificationCoordinator.refreshAllNotifications(for: bills)
            task.setTaskCompleted(success: true)
        } catch {
            print("[BackgroundRefresh] App refresh failed: \(error)")
            task.setTaskCompleted(success: false)
        }
    }

    func handleProcessingTask(
        task: BGProcessingTask,
        modelContainer: ModelContainer
    ) async {
        // Schedule next tasks first
        try? scheduleProcessingTask()
        try? scheduleAppRefresh()

        // Set up expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Bill>()

        do {
            let bills = try context.fetch(descriptor)
            try await notificationCoordinator.refreshAllNotifications(for: bills)
            task.setTaskCompleted(success: true)
        } catch {
            print("[BackgroundRefresh] Processing task failed: \(error)")
            task.setTaskCompleted(success: false)
        }
    }
}
```

### 4. Integration with BilloApp

```swift
@main
struct BilloApp: App {
    @Environment(\.scenePhase) private var scenePhase

    // Add this property
    private let backgroundRefreshManager: BackgroundRefreshManager?

    init() {
        // ... existing init code ...

        // Initialize background refresh (after notificationCoordinator is set up)
        if let coordinator = /* get notification coordinator */ {
            let manager = BackgroundRefreshManager(notificationCoordinator: coordinator)
            manager.registerTasks()
            self.backgroundRefreshManager = manager
        } else {
            self.backgroundRefreshManager = nil
        }
    }

    var body: some Scene {
        WindowGroup {
            // ... existing content ...
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                handleAppBecameActive()
            case .background:
                handleAppEnteredBackground()  // NEW
            default:
                break
            }
        }
    }

    private func handleAppEnteredBackground() {
        // Schedule background tasks when entering background
        try? backgroundRefreshManager?.scheduleAppRefresh()
        try? backgroundRefreshManager?.scheduleProcessingTask()
    }
}
```

### 5. Alternative: Singleton Pattern (Simpler Integration)

If dependency injection for background tasks is complex, use a singleton:

```swift
final class BackgroundRefreshManager {
    static let shared = BackgroundRefreshManager()

    private var notificationCoordinator: NotificationCoordinating?
    private var modelContainer: ModelContainer?

    private init() {}

    func configure(
        notificationCoordinator: NotificationCoordinating,
        modelContainer: ModelContainer
    ) {
        self.notificationCoordinator = notificationCoordinator
        self.modelContainer = modelContainer
    }

    // ... rest of implementation uses stored references ...
}

// In BilloApp.init:
BackgroundRefreshManager.shared.configure(
    notificationCoordinator: coordinator,
    modelContainer: sharedModelContainer
)
BackgroundRefreshManager.shared.registerTasks()
```

---

## Badge Accuracy Strategy with Background Tasks

With background tasks enabled, badge updates happen at multiple points:

| Event | Badge Update Mechanism |
|-------|------------------------|
| App opens | Full recalculation |
| Bill marked paid (in-app) | Decrement immediately |
| Bill marked paid (notification action) | Decrement in handler |
| Notification fires | Badge embedded in notification content* |
| **Background app refresh runs** | Full recalculation |
| **Background processing runs** | Full recalculation |
| Bill created/edited | Recalculation |
| Bill deleted | Decrement |

*Per-notification badge: Each scheduled notification can include a badge count. When the notification fires, iOS updates the badge to that value. This provides accuracy at notification time even without app launch.

### Per-Notification Badge Enhancement

In `NotificationCoordinator.createNotificationRequest()`, add badge to content:

```swift
private func createNotificationRequest(
    for occurrence: BillOccurrence,
    notificationDate: Date,
    offsetDays: Int,
    badgeCountAtFireTime: Int  // NEW parameter
) -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    content.title = occurrence.name
    content.body = contentBuilder.reminderBody(...)
    content.sound = .default
    content.categoryIdentifier = NotificationCategory.billReminder

    // Set badge to count at fire time
    if preferences.badgeEnabled {
        content.badge = NSNumber(value: badgeCountAtFireTime)
    }

    // ... rest of implementation
}
```

**Note:** This requires calculating the expected badge count for each notification's fire date, which adds complexity. Consider only implementing if stale badge is a significant user complaint.

---

## Testing Background Tasks

### Simulating in Xcode

Background tasks can be triggered from Xcode debugger:

```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.billo.refresh"]
```

### Unit Testing

The `BackgroundRefreshManager` doesn't need complex testing - the actual refresh logic is in `NotificationCoordinator` (already tested). Test that:
1. Tasks are scheduled with correct identifiers
2. `handleAppRefresh` calls coordinator's refresh method

```swift
@Suite("BackgroundRefreshManager")
struct BackgroundRefreshManagerTests {
    @Test
    func whenHandleAppRefreshCalled_thenRefreshesNotifications() async {
        // Given
        let coordinatorSpy = NotificationCoordinatorSpy()
        let sut = BackgroundRefreshManager(notificationCoordinator: coordinatorSpy)
        let mockTask = MockBGAppRefreshTask()
        let container = makeInMemoryModelContainer()

        // When
        await sut.handleAppRefresh(task: mockTask, modelContainer: container)

        // Then
        #expect(coordinatorSpy.refreshAllNotificationsCalls.count == 1)
        #expect(mockTask.completedWithSuccess == true)
    }
}
```

---

## Risks & Considerations

| Risk | Mitigation |
|------|------------|
| Background tasks not guaranteed to run | Multiple layers (app refresh + processing); honest UX |
| Battery impact | iOS manages frequency; processing task prefers charging |
| Task terminated before completion | Schedule next task first; handle expiration |
| SwiftData context issues in background | Create fresh ModelContext per task execution |

---

## When to Implement

Implement these improvements if:
1. Users report stale badge counts frequently
2. Users complain about notifications for already-paid bills
3. Analytics show users don't open app frequently (< once per week)

**Do NOT implement if:**
- v1 reliability is acceptable based on user feedback
- App usage patterns show frequent opens (daily/weekly)
- Complexity cost outweighs benefit

---

## Future Enhancement: Server-Side Push

For guaranteed badge accuracy, server-side push notifications are the only solution:

1. Backend tracks bill due dates and payment status
2. Server sends silent push to update badge
3. Server sends visible push for reminders

**Requires:**
- Backend infrastructure (not in v1 scope)
- Apple Push Notification Service setup
- User account/sync system

This is the ultimate solution but significantly increases complexity. Consider only if:
- Billo becomes a multi-device app with sync
- Badge accuracy is critical to user satisfaction
- Resources available for backend development

---

## References

- [Apple: Updating Your App with Background App Refresh](https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background/updating_your_app_with_background_app_refresh)
- [Apple: BGTaskScheduler](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler)
- [WWDC 2019: Advances in App Background Execution](https://developer.apple.com/videos/play/wwdc2019/707/)
