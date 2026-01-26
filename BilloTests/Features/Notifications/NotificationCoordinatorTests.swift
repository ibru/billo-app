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
            let (sut, center, _) = makeSUT(
                remindersEnabled: false,
                digestEnabled: true,
                occurrences: [occurrence],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [occurrence.bill])

            let digestCount = center.addedRequests.filter { NotificationIdentifier.isDigestIdentifier($0.identifier) }.count
            let reminderCount = center.addedRequests.filter { $0.identifier.hasPrefix("billo.r.") }.count
            #expect(digestCount > 0 && reminderCount == 0)
        }

        @Test
        func whenDigestEnabledButNoBillsDueWithinLookahead_thenDoesNotScheduleDigest() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let outsideWindow = makeOccurrence(dueDate: makeDate(2025, 12, 30))
            let (sut, center, _) = makeSUT(
                remindersEnabled: true,
                digestEnabled: true,
                occurrences: [outsideWindow],
                referenceDate: referenceDate
            )
            center.pendingNotifications = [makeDigestRequest(for: referenceDate)]

            try await sut.refreshAllNotifications(for: [outsideWindow.bill])

            let digestScheduled = center.addedRequests.contains { NotificationIdentifier.isDigestIdentifier($0.identifier) }
            #expect(digestScheduled == false)
            #expect(center.allRemovedIdentifiers.contains(where: NotificationIdentifier.isDigestIdentifier))
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
            let (sut, center, _) = makeSUT(
                remindersEnabled: false,
                digestEnabled: true,
                digestLookaheadDays: 7,
                occurrences: occurrences,
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: occurrences.map(\.bill))

            let digestID = NotificationIdentifier.digestIdentifier(for: referenceDate, calendar: testCalendar)
            let digest = center.addedRequests.first { $0.identifier == digestID }
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
            let (sut, center, _) = makeSUT(
                remindersEnabled: false,
                badgeMode: .daysBefore(1),
                occurrences: [overdueBill, futureBill],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [overdueBill.bill, futureBill.bill])

            #expect(center.lastBadgeCount == 1)
        }

        @Test
        func whenManyOccurrencesExceedCap_thenSchedulesMaximum64Reminders() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let occurrences = makeOccurrences(count: 20, dueDate: makeDate(2025, 12, 15))
            let (sut, center, _) = makeSUT(
                remindersEnabled: true,
                reminderOffsets: [0, 3, 5, 7],
                occurrences: occurrences,
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: occurrences.map(\.bill))

            #expect(center.totalAddedCount == 64)
        }

        @Test
        func whenRefreshingWithRemindersEnabled_thenOccurrenceProviderIsCalledOnce() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let occurrence = makeOccurrence(dueDate: makeDate(2025, 12, 10))
            let (sut, _, provider) = makeSUT(
                remindersEnabled: true,
                reminderOffsets: [0, 3],
                occurrences: [occurrence],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [occurrence.bill])

            #expect(provider.unpaidOccurrencesCalls.count == 1)
            #expect(provider.unpaidOccurrencesCalls.first?.horizonDays == 90)
        }

        @Test
        func whenRemindersDisabledAndDigestEnabled_thenOccurrenceProviderIsCalledOnce() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let occurrence = makeOccurrence(dueDate: makeDate(2025, 12, 2))
            let (sut, _, provider) = makeSUT(
                remindersEnabled: false,
                digestEnabled: true,
                digestLookaheadDays: 7,
                occurrences: [occurrence],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [occurrence.bill])

            #expect(provider.unpaidOccurrencesCalls.count == 1)
            #expect(provider.unpaidOccurrencesCalls.first?.horizonDays == 90)
        }

        @Test
        func whenRemindersEnabledButOffsetsEmpty_thenSchedulesNoReminders() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let occurrence = makeOccurrence(dueDate: makeDate(2025, 12, 15))
            let (sut, center, _) = makeSUT(
                remindersEnabled: true,
                reminderOffsets: [],
                digestEnabled: false,
                badgeMode: .never,
                occurrences: [occurrence],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [occurrence.bill])

            let reminderCount = center.addedRequests.filter { $0.identifier.hasPrefix("billo.r.") }.count
            #expect(reminderCount == 0)
        }

        @Test
        func whenOffsetsEmptyAndDigestEnabled_thenSchedulesDigest() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let occurrence = makeOccurrence(dueDate: makeDate(2025, 12, 2))
            let (sut, center, _) = makeSUT(
                remindersEnabled: true,
                reminderOffsets: [],
                digestEnabled: true,
                digestLookaheadDays: 7,
                occurrences: [occurrence],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [occurrence.bill])

            let digestScheduled = center.addedRequests.contains { NotificationIdentifier.isDigestIdentifier($0.identifier) }
            #expect(digestScheduled)
        }

        @Test
        func whenPermissionDenied_thenClearsBadgeAndSchedulesNothing() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let occurrence = makeOccurrence(dueDate: makeDate(2025, 12, 5))
            let (sut, center, _) = makeSUT(
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
            let (sut, center, _) = makeSUT(
                remindersEnabled: false,
                digestEnabled: true,
                occurrences: [usdBill, eurBill],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [usdBill.bill, eurBill.bill])

            let digestID = NotificationIdentifier.digestIdentifier(for: referenceDate, calendar: testCalendar)
            let digest = center.addedRequests.first { $0.identifier == digestID }
            #expect(digest != nil)
            #expect(digest?.content.title == "2 bills due in next 5 days")
            #expect(digest?.content.body == """
            Rent — $10.00 — Dec 2
            Gym — €20.00 — Dec 3
            """)
            #expect(digest?.content.body.contains("USD") == false)
        }

        @Test
        func whenOnlyOverdue_thenDigestUsesOverdueTitle() async throws {
            let referenceDate = makeDate(2025, 12, 5)
            let overdue = makeOccurrence(dueDate: makeDate(2025, 12, 1), name: "Rent", amount: 10)
            let (sut, center, _) = makeSUT(
                remindersEnabled: false,
                digestEnabled: true,
                occurrences: [overdue],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [overdue.bill])

            let digestID = NotificationIdentifier.digestIdentifier(for: referenceDate, calendar: testCalendar)
            let digest = center.addedRequests.first { $0.identifier == digestID }
            #expect(digest?.content.title == "1 bill is overdue")
            #expect(digest?.content.body == "Rent — $10.00 — Dec 1")
        }

        @Test
        func whenBadgeModeIsNever_thenBadgeIsCleared() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let occurrence = makeOccurrence(dueDate: makeDate(2025, 12, 2))
            let (sut, center, _) = makeSUT(
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
            let (sut, center, _) = makeSUT(
                remindersEnabled: true,
                reminderOffsets: [0, 3],
                occurrences: [occurrence],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [occurrence.bill])

            let reminderCount = center.addedRequests.filter { $0.identifier.hasPrefix("billo.r.") }.count
            #expect(reminderCount == 2)
        }

        @Test
        func whenDigestHasSingleBillAndReminderWouldFire_thenDoesNotScheduleDigest() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let occurrence = makeOccurrence(dueDate: makeDate(2025, 12, 3))
            let (sut, center, _) = makeSUT(
                remindersEnabled: true,
                reminderOffsets: [0],
                digestEnabled: true,
                digestLookaheadDays: 5,
                occurrences: [occurrence],
                referenceDate: referenceDate
            )
            center.pendingNotifications = [makeDigestRequest(for: referenceDate)]

            try await sut.refreshAllNotifications(for: [occurrence.bill])

            let digestScheduled = center.addedRequests.contains { NotificationIdentifier.isDigestIdentifier($0.identifier) }
            #expect(digestScheduled == false)
            #expect(center.allRemovedIdentifiers.contains(where: NotificationIdentifier.isDigestIdentifier))
        }

        @Test
        func whenSingleUpcomingAndOverdue_thenSchedulesDigestEvenIfReminderExists() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let upcoming = makeOccurrence(dueDate: makeDate(2025, 12, 3))
            let overdue = makeOccurrence(dueDate: makeDate(2025, 11, 29))
            let (sut, center, _) = makeSUT(
                remindersEnabled: true,
                reminderOffsets: [0],
                digestEnabled: true,
                digestLookaheadDays: 5,
                occurrences: [upcoming, overdue],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [upcoming.bill, overdue.bill])

            let digestScheduled = center.addedRequests.contains { NotificationIdentifier.isDigestIdentifier($0.identifier) }
            #expect(digestScheduled)
        }

        @Test
        func whenDigestHasSingleBillAndRemindersDisabled_thenSchedulesDigest() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let occurrence = makeOccurrence(dueDate: makeDate(2025, 12, 3))
            let (sut, center, _) = makeSUT(
                remindersEnabled: false,
                digestEnabled: true,
                digestLookaheadDays: 5,
                occurrences: [occurrence],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [occurrence.bill])

            let digestScheduled = center.addedRequests.contains { NotificationIdentifier.isDigestIdentifier($0.identifier) }
            #expect(digestScheduled)
        }

        @Test
        func whenDigestHasSingleBillAndOffsetsEmpty_thenSchedulesDigest() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let occurrence = makeOccurrence(dueDate: makeDate(2025, 12, 3))
            let (sut, center, _) = makeSUT(
                remindersEnabled: true,
                reminderOffsets: [],
                digestEnabled: true,
                digestLookaheadDays: 5,
                occurrences: [occurrence],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [occurrence.bill])

            let digestScheduled = center.addedRequests.contains { NotificationIdentifier.isDigestIdentifier($0.identifier) }
            #expect(digestScheduled)
        }

        @Test
        func whenDigestHasSingleBillAndReminderTimeAlreadyPassed_thenSchedulesDigest() async throws {
            let referenceDate = makeDateTime(2025, 12, 1, hour: 10, minute: 0)
            let occurrence = makeOccurrence(dueDate: makeDate(2025, 12, 2))
            let (sut, center, _) = makeSUT(
                remindersEnabled: true,
                reminderOffsets: [1],
                reminderTime: DateComponents(hour: 9, minute: 0),
                digestEnabled: true,
                digestLookaheadDays: 5,
                occurrences: [occurrence],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [occurrence.bill])

            let digestScheduled = center.addedRequests.contains { NotificationIdentifier.isDigestIdentifier($0.identifier) }
            #expect(digestScheduled)
        }

        @Test
        func whenDigestHasMultipleBillsAndSingleWouldHaveReminder_thenSchedulesDigest() async throws {
            let referenceDate = makeDate(2025, 12, 1)
            let firstOccurrence = makeOccurrence(dueDate: makeDate(2025, 12, 3))
            let secondOccurrence = makeOccurrence(dueDate: makeDate(2025, 12, 4))
            let (sut, center, _) = makeSUT(
                remindersEnabled: true,
                reminderOffsets: [0],
                digestEnabled: true,
                digestLookaheadDays: 5,
                occurrences: [firstOccurrence, secondOccurrence],
                referenceDate: referenceDate
            )

            try await sut.refreshAllNotifications(for: [firstOccurrence.bill, secondOccurrence.bill])

            let digestScheduled = center.addedRequests.contains { NotificationIdentifier.isDigestIdentifier($0.identifier) }
            #expect(digestScheduled)
        }
    }

    @Suite("cancellation")
    @MainActor
    struct Cancellation {

        @Test
        func whenPermissionDenied_thenCancelAllBillRemindersRemovesExistingReminderRequests() async throws {
            let reminderOccurrence = makeOccurrence(dueDate: makeDate(2025, 12, 1))
            let reminderRequest = makeReminderRequest(for: reminderOccurrence, offsetDays: 0)
            let digestRequest = makeDigestRequest(for: makeDate(2025, 12, 1))
            let (sut, center, _) = makeSUT(authorizationStatus: .denied)
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

            let (sut, center, _) = makeSUT()
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

            let (sut, center, _) = makeSUT()
            center.pendingNotifications = [targetReminderEarly, targetReminderLate, unrelatedReminder]

            await sut.cancelAllReminders(forBillID: targetOccurrence.bill.stableID)

            #expect(Set(center.allRemovedIdentifiers) == Set([targetReminderEarly.identifier, targetReminderLate.identifier]))
            #expect(center.pendingNotifications.map(\.identifier) == [unrelatedReminder.identifier])
        }

        @Test
        func whenReschedulingWithRemindersEnabled_thenCancelsExistingAndSchedulesNewOffsets() async throws {
            let existingOccurrence = makeOccurrence(dueDate: makeDate(2025, 12, 1))
            let newOccurrence = makeOccurrence(dueDate: makeDate(2025, 12, 5))
            let existingReminder = makeReminderRequest(for: existingOccurrence, offsetDays: 0)

            let referenceDate = makeDate(2025, 11, 30)
            let (sut, center, _) = makeSUT(remindersEnabled: true, reminderOffsets: [0, 3], referenceDate: referenceDate)
            center.pendingNotifications = [existingReminder]

            try await sut.rescheduleReminders(
                forBillID: existingOccurrence.bill.stableID,
                newOccurrences: [newOccurrence]
            )

            #expect(Set(center.allRemovedIdentifiers) == Set([existingReminder.identifier]))

            let scheduledReminders = center.addedRequests.filter { $0.identifier.hasPrefix("billo.r.") }
            let expectedPrefix = NotificationIdentifier.prefix(
                forBillIDHash: NotificationIdentifier.shortHash(
                    of: newOccurrence.bill.stableID
                )
            )

            #expect(scheduledReminders.count == 2)
            #expect(scheduledReminders.allSatisfy { $0.identifier.hasPrefix(expectedPrefix) })
        }

        @Test
        func whenRemindersDisabled_thenRescheduleRemindersOnlyCancelsExistingRequests() async throws {
            let occurrence = makeOccurrence(dueDate: makeDate(2025, 12, 3))
            let existingReminder = makeReminderRequest(for: occurrence, offsetDays: 0)

            let (sut, center, _) = makeSUT(remindersEnabled: false)
            center.pendingNotifications = [existingReminder]

            try await sut.rescheduleReminders(
                forBillID: occurrence.bill.stableID,
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
    reminderTime: DateComponents = DateComponents(hour: 9, minute: 0),
    digestEnabled: Bool = false,
    digestLookaheadDays: Int = 5,
    badgeMode: BadgeMode = .daysBefore(3),
    occurrences: [BillOccurrence] = [],
    referenceDate: Date = Date()
) -> (sut: NotificationCoordinator, center: UNNotificationCenterSpy, provider: BillOccurrenceProviderStub) {
    let center = UNNotificationCenterSpy()
    center.stubbedAuthorizationStatus = authorizationStatus

    let prefs = NotificationPreferencesStub()
    prefs.remindersEnabled = remindersEnabled
    prefs.reminderOffsets = reminderOffsets
    prefs.reminderTime = reminderTime
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

    return (sut, center, provider)
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

private func makeDateTime(_ year: Int, _ month: Int, _ day: Int, hour: Int, minute: Int) -> Date {
    let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
    return testCalendar.date(from: components)!
}

@MainActor
private func makeOccurrence(
    dueDate: Date,
    name: String = "Test Bill",
    currency: String = "USD",
    amount: Decimal = 100
) -> BillOccurrence {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Bill.self, PaymentEntry.self, IssuedOccurrence.self, configurations: config)
    let context = ModelContext(container)

    let bill = Bill(
        name: name,
        amount: amount,
        currencyCode: currency,
        dueDate: dueDate
    )
    context.insert(bill)
    try? context.save()
    return BillOccurrence(bill: bill, dueDate: dueDate, calendar: testCalendar)
}

@MainActor
private func makeOccurrences(count: Int, startingFrom referenceDate: Date) -> [BillOccurrence] {
    (0..<count).map { idx in
        let date = testCalendar.date(byAdding: .day, value: idx + 1, to: referenceDate)!
        return makeOccurrence(dueDate: date)
    }
}

@MainActor
private func makeOccurrences(count: Int, dueDate: Date) -> [BillOccurrence] {
    (0..<count).map { idx in
        makeOccurrence(dueDate: dueDate, name: "Bill \(idx + 1)", amount: Decimal(idx + 1))
    }
}

@MainActor
private func makeReminderRequest(for occurrence: BillOccurrence, offsetDays: Int) -> UNNotificationRequest {
    let billIDString = occurrence.bill.stableID
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
private func makeDigestRequest(for date: Date) -> UNNotificationRequest {
    UNNotificationRequest(
        identifier: NotificationIdentifier.digestIdentifier(for: date, calendar: testCalendar),
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
