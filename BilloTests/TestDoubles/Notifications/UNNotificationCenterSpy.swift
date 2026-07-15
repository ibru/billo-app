//  Created by Jiri Urbasek on 12/02/25.

import Foundation
import UserNotifications
@testable import Billo

// MARK: - UNNotificationCenterSpy

final class UNNotificationCenterSpy: UNNotificationCenterProtocol, @unchecked Sendable {
    // MARK: - Captured calls

    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedIdentifiers: [[String]] = []
    private(set) var badgeCounts: [Int] = []
    private(set) var requestAuthorizationCallCount = 0
    /// One increment per `refreshAllNotifications` pass — the coordinator
    /// checks authorization exactly once per pass, so this counts passes.
    private(set) var authorizationStatusCallCount = 0

    // MARK: - Stubbed responses

    var pendingNotifications: [UNNotificationRequest] = []
    var stubbedAuthorizationStatus: UNAuthorizationStatus = .authorized
    var requestAuthorizationResult: Result<Bool, Error> = .success(true)
    var addRequestError: Error?
    /// Awaited inside `authorizationStatus()` with the 1-based call index.
    /// Lets a test suspend a chosen refresh pass mid-flight to exercise
    /// overlap behavior deterministically. No-op when nil.
    var onAuthorizationStatus: (@Sendable (Int) async -> Void)?

    // MARK: - Protocol implementation

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthorizationCallCount += 1
        return try requestAuthorizationResult.get()
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatusCallCount += 1
        await onAuthorizationStatus?(authorizationStatusCallCount)
        return stubbedAuthorizationStatus
    }

    func add(_ request: UNNotificationRequest) async throws {
        if let error = addRequestError { throw error }
        addedRequests.append(request)
        pendingNotifications.append(request)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pendingNotifications
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(identifiers)
        pendingNotifications.removeAll { identifiers.contains($0.identifier) }
    }

    func removeAllPendingNotificationRequests() {
        pendingNotifications.removeAll()
    }

    func setBadgeCount(_ count: Int) async throws {
        badgeCounts.append(count)
    }

    // MARK: - Test helpers

    var lastBadgeCount: Int? { badgeCounts.last }
    var totalAddedCount: Int { addedRequests.count }
    var allRemovedIdentifiers: [String] { removedIdentifiers.flatMap { $0 } }
}

// MARK: - NotificationPreferencesStub

@MainActor
final class NotificationPreferencesStub: NotificationPreferencesReading, @unchecked Sendable {
    var remindersEnabled: Bool = true
    var reminderOffsets: [Int] = [0, 3]
    var reminderTime: DateComponents = DateComponents(hour: 9, minute: 0)
    var digestEnabled: Bool = false
    var digestLookaheadDays: Int = 5
    var digestTime: DateComponents = DateComponents(hour: 9, minute: 0)
    var badgeMode: BadgeMode = .daysBefore(3)

    // Factory for common configurations
    @MainActor
    static func withRemindersDisabled() -> NotificationPreferencesStub {
        let stub = NotificationPreferencesStub()
        stub.remindersEnabled = false
        return stub
    }

    @MainActor
    static func withBadgeMode(_ mode: BadgeMode) -> NotificationPreferencesStub {
        let stub = NotificationPreferencesStub()
        stub.badgeMode = mode
        return stub
    }

    @MainActor
    static func withDigestEnabled(lookahead: Int = 5) -> NotificationPreferencesStub {
        let stub = NotificationPreferencesStub()
        stub.digestEnabled = true
        stub.digestLookaheadDays = lookahead
        return stub
    }

    @MainActor
    static func withAllOffsets() -> NotificationPreferencesStub {
        let stub = NotificationPreferencesStub()
        stub.reminderOffsets = [0, 3, 5, 7]
        return stub
    }
}
