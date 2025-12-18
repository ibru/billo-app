//  Created by Jiri Urbasek on 12/02/25.

import Testing
import Foundation
import UserNotifications
import SwiftData
@testable import Billo

@Suite("NotificationCoordinator")
struct NotificationCoordinatorTests {

    @Suite("refreshAllNotifications")
    @MainActor
    struct RefreshAllNotifications {

        @Test
        func whenRemindersDisabledAndDigestEnabled_thenSchedulesDigestOnly() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let occurrence = makeOccurrence(dueDate: makeDate(2025, 12, 2))
            let (sut, center) = makeSUT(
                remindersEnabled: false,
                digestEnabled: true,
                occurrences: [occurrence],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [occurrence.bill])

            let digestScheduled = center.addedRequests.contains { $0.identifier == NotificationIdentifier.digestIdentifier }
            let reminderCount = center.addedRequests.filter { $0.identifier.hasPrefix("billo.r.") }.count
            #expect(digestScheduled && reminderCount == 0)
        }

        @Test
        func whenDigestEnabledButNoBillsDueWithinLookahead_thenDoesNotScheduleDigest() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let outsideWindow = makeOccurrence(dueDate: makeDate(2025, 12, 20))
            let (sut, center) = makeSUT(
                remindersEnabled: false,
                digestEnabled: true,
                occurrences: [outsideWindow],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [outsideWindow.bill])

            let digestScheduled = center.addedRequests.contains { $0.identifier == NotificationIdentifier.digestIdentifier }
            #expect(digestScheduled == false)
        }

        @Test
        func whenMoreThanFiveBillsDueWithinLookahead_thenDigestListsFirstFiveAndTruncates() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let occurrences = (1...7).map { idx in
                makeOccurrence(
                    dueDate: makeDate(2025, 12, 1 + idx),
                    name: "Bill \(idx)",
                    currency: "USD",
                    amount: Decimal(idx)
                )
            }
            let (sut, center) = makeSUT(
                remindersEnabled: false,
                digestEnabled: true,
                digestLookaheadDays: 7,
                occurrences: occurrences,
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: occurrences.map(\.bill))

            let digest = center.addedRequests.first { $0.identifier == NotificationIdentifier.digestIdentifier }
            #expect(digest?.content.title == "7 bills due in next 7 days")
            #expect(digest?.content.body == """
            Bill 1 — $1.00 — Dec 2
            Bill 2 — $2.00 — Dec 3
            Bill 3 — $3.00 — Dec 4
            Bill 4 — $4.00 — Dec 5
            Bill 5 — $5.00 — Dec 6
            …and 2 more
            """)
        }

        @Test
        func whenBadgeModeIsOneDay_thenBadgeCountsOnlyDueSoonOrOverdue() async throws {
            let referenceDate = makeDate(2025, 12, 10)
            let overdueBill = makeOccurrence(dueDate: makeDate(2025, 12, 9))
            let futureBill = makeOccurrence(dueDate: makeDate(2025, 12, 15))
            let (sut, center) = makeSUT(
                remindersEnabled: false,
                badgeMode: .daysBefore(1),
                occurrences: [overdueBill, futureBill],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [overdueBill.bill, futureBill.bill])

            #expect(center.lastBadgeCount == 1)
        }

        @Test
        func whenManyOccurrencesExceedCap_thenSchedulesMaximum60Reminders() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let occurrences = makeOccurrences(count: 40, startingFrom: referenceDate)
            let (sut, center) = makeSUT(
                remindersEnabled: true,
                reminderOffsets: [0, 3, 5, 7],
                occurrences: occurrences,
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: occurrences.map(\.bill))

            #expect(center.totalAddedCount == 60)
        }

        @Test
        func whenPermissionDenied_thenClearsBadgeAndSchedulesNothing() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let occurrence = makeOccurrence(dueDate: makeDate(2025, 12, 5))
            let (sut, center) = makeSUT(
                authorizationStatus: .denied,
                remindersEnabled: true,
                occurrences: [occurrence],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [occurrence.bill])

            #expect(center.totalAddedCount == 0 && center.lastBadgeCount == 0)
        }

        @Test
        func whenBillsHaveMixedCurrencies_thenDigestListsFirstBillsWithIndividualAmounts() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let usdBill = makeOccurrence(dueDate: makeDate(2025, 12, 2), name: "Rent", currency: "USD", amount: 10)
            let eurBill = makeOccurrence(dueDate: makeDate(2025, 12, 3), name: "Gym", currency: "EUR", amount: 20)
            let (sut, center) = makeSUT(
                remindersEnabled: false,
                digestEnabled: true,
                occurrences: [usdBill, eurBill],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [usdBill.bill, eurBill.bill])

            let digest = center.addedRequests.first { $0.identifier == NotificationIdentifier.digestIdentifier }
            #expect(digest != nil)
            #expect(digest?.content.title == "2 bills due in next 5 days")
            #expect(digest?.content.body == """
            Rent — $10.00 — Dec 2
            Gym — €20.00 — Dec 3
            """)
            #expect(digest?.content.body.contains("USD") == false)
        }

        @Test
        func whenBadgeModeIsNever_thenBadgeIsCleared() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let occurrence = makeOccurrence(dueDate: makeDate(2025, 12, 2))
            let (sut, center) = makeSUT(
                remindersEnabled: false,
                badgeMode: .never,
                occurrences: [occurrence],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [occurrence.bill])

            #expect(center.lastBadgeCount == 0)
        }

        @Test
        func whenRemindersEnabled_thenSchedulesRemindersForEachOffset() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let occurrence = makeOccurrence(dueDate: makeDate(2025, 12, 10))
            let (sut, center) = makeSUT(
                remindersEnabled: true,
                reminderOffsets: [0, 3],
                occurrences: [occurrence],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [occurrence.bill])

            let reminderCount = center.addedRequests.filter { $0.identifier.hasPrefix("billo.r.") }.count
            #expect(reminderCount == 2)
        }
    }

    @Suite("cancellation")
    @MainActor
    struct Cancellation {

        @Test
        func whenPermissionDenied_thenCancelAllBillRemindersRemovesExistingReminderRequests() async throws {
            let reminderOccurrence = makeOccurrence(dueDate: makeDate(2025, 12, 1))
            let reminderRequest = makeReminderRequest(for: reminderOccurrence, offsetDays: 0)
            let digestRequest = makeDigestRequest()
            let (sut, center) = makeSUT(authorizationStatus: .denied)
            center.pendingNotifications = [reminderRequest, digestRequest]

            try await sut.refreshAllNotifications(for: [])

            #expect(center.allRemovedIdentifiers == [digestRequest.identifier, reminderRequest.identifier])
            #expect(center.pendingNotifications.isEmpty)
        }

        @Test
        func whenSpecificOccurrencesProvided_thenCancelRemindersRemovesMatchingRequests() async throws {
            let firstOccurrence = makeOccurrence(dueDate: makeDate(2025, 12, 5))
            let secondOccurrence = makeOccurrence(dueDate: makeDate(2025, 12, 6))
            let otherOccurrence = makeOccurrence(dueDate: makeDate(2025, 12, 7))

            let firstReminder = makeReminderRequest(for: firstOccurrence, offsetDays: 0)
            let secondReminder = makeReminderRequest(for: secondOccurrence, offsetDays: 3)
            let otherReminder = makeReminderRequest(for: otherOccurrence, offsetDays: 0)

            let (sut, center) = makeSUT()
            center.pendingNotifications = [firstReminder, secondReminder, otherReminder]

            await sut.cancelReminders(for: [firstOccurrence.id, secondOccurrence.id])

            #expect(Set(center.allRemovedIdentifiers) == Set([firstReminder.identifier, secondReminder.identifier]))
            #expect(center.pendingNotifications.map(\.identifier) == [otherReminder.identifier])
        }

        @Test
        func whenCancellingBillReminders_thenRemovesOnlyIdentifiersMatchingBillPrefix() async throws {
            let targetOccurrence = makeOccurrence(dueDate: makeDate(2025, 12, 10))
            let targetReminderEarly = makeReminderRequest(for: targetOccurrence, offsetDays: 0)
            let targetReminderLate = makeReminderRequest(for: targetOccurrence, offsetDays: 5)
            let unrelatedReminder = makeCustomReminderRequest(identifier: "unrelated.id")

            let (sut, center) = makeSUT()
            center.pendingNotifications = [targetReminderEarly, targetReminderLate, unrelatedReminder]

            await sut.cancelAllReminders(forBillID: String(describing: targetOccurrence.bill.persistentModelID))

            #expect(Set(center.allRemovedIdentifiers) == Set([targetReminderEarly.identifier, targetReminderLate.identifier]))
            #expect(center.pendingNotifications.map(\.identifier) == [unrelatedReminder.identifier])
        }

        @Test
        func whenReschedulingWithRemindersEnabled_thenCancelsExistingAndSchedulesNewOffsets() async throws {
            let existingOccurrence = makeOccurrence(dueDate: makeDate(2025, 12, 1))
            let newOccurrence = makeOccurrence(dueDate: makeDate(2025, 12, 5))
            let existingReminder = makeReminderRequest(for: existingOccurrence, offsetDays: 0)

            let referenceDate = makeDate(2025, 11, 30)
            let (sut, center) = makeSUT(remindersEnabled: true, reminderOffsets: [0, 3], referenceDate: referenceDate)
            center.pendingNotifications = [existingReminder]

            try await sut.rescheduleReminders(
                forBillID: String(describing: existingOccurrence.bill.persistentModelID),
                newOccurrences: [newOccurrence]
            )

            #expect(Set(center.allRemovedIdentifiers) == Set([existingReminder.identifier]))

            let scheduledReminders = center.addedRequests.filter { $0.identifier.hasPrefix("billo.r.") }
            let expectedPrefix = NotificationIdentifier.prefix(
                forBillIDHash: NotificationIdentifier.shortHash(
                    of: String(describing: newOccurrence.bill.persistentModelID)
                )
            )

            #expect(scheduledReminders.count == 2)
            #expect(scheduledReminders.allSatisfy { $0.identifier.hasPrefix(expectedPrefix) })
        }

        @Test
        func whenRemindersDisabled_thenRescheduleRemindersOnlyCancelsExistingRequests() async throws {
            let occurrence = makeOccurrence(dueDate: makeDate(2025, 12, 3))
            let existingReminder = makeReminderRequest(for: occurrence, offsetDays: 0)

            let (sut, center) = makeSUT(remindersEnabled: false)
            center.pendingNotifications = [existingReminder]

            try await sut.rescheduleReminders(
                forBillID: String(describing: occurrence.bill.persistentModelID),
                newOccurrences: [occurrence]
            )

            #expect(Set(center.allRemovedIdentifiers) == Set([existingReminder.identifier]))
            #expect(center.addedRequests.isEmpty)
        }
    }
}

// MARK: - makeSUT & Factories

@MainActor
private func makeSUT(
    authorizationStatus: UNAuthorizationStatus = .authorized,
    remindersEnabled: Bool = true,
    reminderOffsets: [Int] = [0, 3],
    digestEnabled: Bool = false,
    digestLookaheadDays: Int = 5,
    badgeMode: BadgeMode = .daysBefore(3),
    occurrences: [BillOccurrence] = [],
    referenceDate: Date = Date()
) -> (sut: NotificationCoordinator, center: UNNotificationCenterSpy) {
    let center = UNNotificationCenterSpy()
    center.stubbedAuthorizationStatus = authorizationStatus

    let prefs = NotificationPreferencesStub()
    prefs.remindersEnabled = remindersEnabled
    prefs.reminderOffsets = reminderOffsets
    prefs.digestEnabled = digestEnabled
    prefs.digestLookaheadDays = digestLookaheadDays
    prefs.badgeMode = badgeMode

    let provider = BillOccurrenceProviderStub.returning(occurrences)
    let contentBuilder = NotificationContentBuilder(
        locale: Locale(identifier: "en_US"),
        timeZone: TimeZone(identifier: "UTC")!
    )

    let sut = NotificationCoordinator(
        notificationCenter: center,
        preferences: prefs,
        occurrenceProvider: provider,
        contentBuilder: contentBuilder,
        calendar: testCalendar,
        currentDate: { referenceDate }
    )

    return (sut, center)
}

private let testCalendar: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    cal.locale = Locale(identifier: "en_US")
    return cal
}()

private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    let components = DateComponents(year: year, month: month, day: day, hour: 0, minute: 0)
    return testCalendar.date(from: components)!
}

@MainActor
private func makeOccurrence(
    dueDate: Date,
    name: String = "Test Bill",
    currency: String = "USD",
    amount: Decimal = 100
) -> BillOccurrence {
    let bill = Bill(
        name: name,
        amount: amount,
        currencyCode: currency,
        dueDate: dueDate
    )
    return BillOccurrence(bill: bill, dueDate: dueDate)
}

@MainActor
private func makeOccurrences(count: Int, startingFrom referenceDate: Date) -> [BillOccurrence] {
    (0..<count).map { idx in
        let date = testCalendar.date(byAdding: .day, value: idx + 1, to: referenceDate)!
        return makeOccurrence(dueDate: date)
    }
}

@MainActor
private func makeReminderRequest(for occurrence: BillOccurrence, offsetDays: Int) -> UNNotificationRequest {
    let billIDString = String(describing: occurrence.bill.persistentModelID)
    let identifier = NotificationIdentifier(
        billIDHash: NotificationIdentifier.shortHash(of: billIDString),
        occurrenceTimestamp: Int(occurrence.dueDate.timeIntervalSinceReferenceDate),
        offsetDays: offsetDays
    ).stringValue

    return UNNotificationRequest(
        identifier: identifier,
        content: UNMutableNotificationContent(),
        trigger: nil
    )
}

@MainActor
private func makeDigestRequest() -> UNNotificationRequest {
    UNNotificationRequest(
        identifier: NotificationIdentifier.digestIdentifier,
        content: UNMutableNotificationContent(),
        trigger: nil
    )
}

private func makeCustomReminderRequest(identifier: String) -> UNNotificationRequest {
    UNNotificationRequest(
        identifier: identifier,
        content: UNMutableNotificationContent(),
        trigger: nil
    )
}
