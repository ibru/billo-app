//  Created by Jiri Urbasek on 02/10/26.

import Testing
import SwiftData
import Foundation
@testable import Billo

@Suite("NotificationActionHandler") @MainActor
struct NotificationActionHandlerTests {

    @Test func whenTimestampAtMidnight_thenRecordsPayment() async throws {
        let calendar = makeUTCCalendar()
        let (sut, container, coordinatorSpy, prefs) = try makeSUT(calendar: calendar)

        let dueDate = makeDate(year: 2025, month: 1, day: 15)
        try insertBill(
            amount: 100,
            dueDate: dueDate,
            stableID: "bill-1",
            calendar: calendar,
            in: container
        )

        let timestamp = Int(dueDate.timeIntervalSinceReferenceDate)
        let identifier = makeNotificationIdentifier(billStableID: "bill-1", timestamp: timestamp)

        await sut.handleMarkPaid(
            notificationIdentifier: identifier,
            modelContainer: container,
            notificationCoordinator: coordinatorSpy,
            notificationPreferences: prefs
        )

        let payments = try fetchPaymentEntries(from: container)
        #expect(payments.count == 1)
        #expect(payments.first?.amount == 100)
    }

    @Test func whenTimestampHasTimeComponents_thenStillRecordsPayment() async throws {
        let calendar = makeUTCCalendar()
        let (sut, container, coordinatorSpy, prefs) = try makeSUT(calendar: calendar)

        let dueDate = makeDate(year: 2025, month: 1, day: 15)
        try insertBill(
            amount: 100,
            dueDate: dueDate,
            stableID: "bill-1",
            calendar: calendar,
            in: container
        )

        // Timestamp 30 minutes past midnight should still resolve to the correct occurrence amount.
        let nonMidnight = dueDate.addingTimeInterval(30 * 60)
        let timestamp = Int(nonMidnight.timeIntervalSinceReferenceDate)
        let identifier = makeNotificationIdentifier(billStableID: "bill-1", timestamp: timestamp)

        await sut.handleMarkPaid(
            notificationIdentifier: identifier,
            modelContainer: container,
            notificationCoordinator: coordinatorSpy,
            notificationPreferences: prefs
        )

        let payments = try fetchPaymentEntries(from: container)
        #expect(payments.count == 1)
        #expect(payments.first?.amount == 100)
    }

    @Test func whenHandlingInDifferentTimezone_thenPreservesOriginalOccurrenceTimestamp() async throws {
        let billCalendar = makeUTCCalendar()
        var actionCalendar = Calendar(identifier: .gregorian)
        actionCalendar.timeZone = TimeZone(identifier: "Pacific/Honolulu")!

        let (sut, container, coordinatorSpy, prefs) = try makeSUT(calendar: actionCalendar)

        // Bill due at midnight UTC. The issued snapshot is keyed to this exact UTC day.
        let dueDate = makeDate(year: 2025, month: 1, day: 15)
        try insertBillWithSnapshot(
            currentAmount: 100,
            snapshotAmount: 200,
            dueDate: dueDate,
            stableID: "bill-1",
            calendar: billCalendar,
            in: container
        )

        // Notification identifier carries original occurrence timestamp (scheduled in UTC).
        let timestamp = Int(dueDate.timeIntervalSinceReferenceDate)
        let identifier = makeNotificationIdentifier(billStableID: "bill-1", timestamp: timestamp)

        await sut.handleMarkPaid(
            notificationIdentifier: identifier,
            modelContainer: container,
            notificationCoordinator: coordinatorSpy,
            notificationPreferences: prefs
        )

        let payments = try fetchPaymentEntries(from: container)
        #expect(payments.count == 1)
        #expect(
            payments.first?.amount == 200,
            "Should use snapshot amount (200) for the encoded occurrence timestamp, regardless of action timezone"
        )
    }
}

// MARK: - makeSUT & Factories

@MainActor
private func makeSUT(
    calendar: Calendar = makeUTCCalendar()
) throws -> (NotificationActionHandler, ModelContainer, NotificationCoordinatorSpy, StubNotificationPreferences) {
    let handler = NotificationActionHandler(calendar: calendar)
    let schema = Schema([Bill.self, RecurrenceRule.self, IssuedOccurrence.self, PaymentEntry.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    let spy = NotificationCoordinatorSpy()
    let prefs = StubNotificationPreferences()
    return (handler, container, spy, prefs)
}

@discardableResult
@MainActor
private func insertBill(
    name: String = "Rent",
    amount: Decimal,
    dueDate: Date,
    stableID: String,
    calendar: Calendar,
    in container: ModelContainer
) throws -> Bill {
    let context = ModelContext(container)
    let bill = Bill(name: name, amount: amount, dueDate: dueDate, stableID: stableID, calendar: calendar)
    context.insert(bill)
    try context.save()
    return bill
}

@discardableResult
@MainActor
private func insertBillWithSnapshot(
    name: String = "Rent",
    currentAmount: Decimal,
    snapshotAmount: Decimal,
    dueDate: Date,
    stableID: String,
    calendar: Calendar,
    in container: ModelContainer
) throws -> Bill {
    let context = ModelContext(container)
    let bill = Bill(name: name, amount: currentAmount, dueDate: dueDate, stableID: stableID, calendar: calendar)
    context.insert(bill)

    let key = bill.occurrenceKey(for: bill.dueDate, calendar: calendar)
    let issued = IssuedOccurrence(
        occurrenceKey: key,
        dueDate: bill.dueDate,
        billName: name,
        billAmount: snapshotAmount,
        billCurrencyCode: "USD",
        billAccountIdentifier: nil,
        billNotes: nil,
        billCategoryRawValue: nil,
        bill: bill
    )
    context.insert(issued)
    try context.save()
    return bill
}

@MainActor
private func makeNotificationIdentifier(billStableID: String, timestamp: Int) -> String {
    let hash = NotificationIdentifier.shortHash(of: billStableID)
    return "billo.r.\(hash)_\(timestamp)_0"
}

@MainActor
private func fetchPaymentEntries(from container: ModelContainer) throws -> [PaymentEntry] {
    let context = ModelContext(container)
    return try context.fetch(FetchDescriptor<PaymentEntry>())
}

private func makeDate(year: Int = 2025, month: Int = 1, day: Int) -> Date {
    let calendar = makeUTCCalendar()
    return calendar.date(from: DateComponents(year: year, month: month, day: day))!
}

private func makeUTCCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

private struct StubNotificationPreferences: NotificationPreferencesReading {
    var remindersEnabled: Bool = true
    var reminderOffsets: [Int] = [0]
    var reminderTime: DateComponents = DateComponents(hour: 9, minute: 0)
    var digestEnabled: Bool = false
    var digestLookaheadDays: Int = 5
    var digestTime: DateComponents = DateComponents(hour: 9, minute: 0)
    var badgeMode: BadgeMode = .never
}
