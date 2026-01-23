//  Created by Jiri Urbasek on 01/22/26.

import Foundation

@MainActor
protocol NotificationRefreshScheduling: Sendable {
    func scheduleRefresh()
}

typealias NotificationRefreshAction = @MainActor @Sendable () async -> Void

@MainActor
final class NotificationRefreshDebouncer: NotificationRefreshScheduling {
    private let delay: Duration
    private let sleep: @Sendable (Duration) async -> Void
    private let refresh: NotificationRefreshAction
    private var task: Task<Void, Never>?

    init(
        delay: Duration = .milliseconds(500),
        sleep: @escaping @Sendable (Duration) async -> Void = { duration in
            try? await Task.sleep(for: duration)
        },
        refresh: @escaping NotificationRefreshAction
    ) {
        self.delay = delay
        self.sleep = sleep
        self.refresh = refresh
    }

    func scheduleRefresh() {
        task?.cancel()
        task = Task { [delay, sleep, refresh] in
            await sleep(delay)
            guard Task.isCancelled == false else { return }
            await refresh()
        }
    }
}

@MainActor
struct NoopNotificationRefreshScheduler: NotificationRefreshScheduling {
    func scheduleRefresh() { }
}
