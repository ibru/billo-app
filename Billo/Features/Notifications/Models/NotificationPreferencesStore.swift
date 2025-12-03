//  Created by Jiri Urbasek on 12/02/25.

import Foundation
import Observation

// MARK: - Protocols

protocol NotificationPreferencesReading: Sendable {
    var remindersEnabled: Bool { get }
    var reminderOffsets: [Int] { get }
    var reminderTime: DateComponents { get }
    var digestEnabled: Bool { get }
    var digestLookaheadDays: Int { get }
    var digestTime: DateComponents { get }
    var badgeMode: BadgeMode { get }
}

protocol NotificationPreferencesWriting: Sendable {
    func setRemindersEnabled(_ enabled: Bool)
    func setReminderOffsets(_ offsets: [Int])
    func setReminderTime(_ time: DateComponents)
    func setDigestEnabled(_ enabled: Bool)
    func setDigestLookaheadDays(_ days: Int)
    func setDigestTime(_ time: DateComponents)
    func setBadgeMode(_ mode: BadgeMode)
}

typealias NotificationPreferencesProviding = NotificationPreferencesReading & NotificationPreferencesWriting

// MARK: - Implementation

@Observable
final class NotificationPreferencesStore: NotificationPreferencesProviding, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let keyPrefix = "billo.notifications."
    private var changeTick: Int = 0

    private enum Keys {
        static let remindersEnabled = "remindersEnabled"
        static let reminderOffsets = "reminderOffsets"
        static let reminderTimeHour = "reminderTimeHour"
        static let reminderTimeMinute = "reminderTimeMinute"
        static let digestEnabled = "digestEnabled"
        static let digestLookaheadDays = "digestLookaheadDays"
        static let digestTimeHour = "digestTimeHour"
        static let digestTimeMinute = "digestTimeMinute"
        static let badgeMode = "badgeMode"
    }

    // MARK: - Constants

    /// All available offset options user can choose from
    static let availableOffsets = [0, 3, 5, 7]  // Day-of, 3, 5, 7 days before

    /// Default enabled offsets for new users
    /// Day-of ensures users get critical same-day alerts; 3 days gives advance notice
    static let defaultReminderOffsets = [0, 3]  // Day-of + 3 days before

    static let defaultReminderTime = DateComponents(hour: 9, minute: 0)
    static let defaultDigestLookaheadDays = 5
    static let defaultDigestTime = DateComponents(hour: 9, minute: 0)
    static let defaultBadgeMode: BadgeMode = .daysBefore(3)

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        registerDefaults()
    }

    private func registerDefaults() {
        // Encode default badge mode
        let defaultBadgeModeData = try? JSONEncoder().encode(Self.defaultBadgeMode)

        userDefaults.register(defaults: [
            keyPrefix + Keys.remindersEnabled: true,  // ON by default (core value)
            keyPrefix + Keys.reminderOffsets: Self.defaultReminderOffsets,
            keyPrefix + Keys.reminderTimeHour: 9,
            keyPrefix + Keys.reminderTimeMinute: 0,
            keyPrefix + Keys.digestEnabled: false,  // Digest is opt-in
            keyPrefix + Keys.digestLookaheadDays: Self.defaultDigestLookaheadDays,
            keyPrefix + Keys.digestTimeHour: 9,
            keyPrefix + Keys.digestTimeMinute: 0,
            keyPrefix + Keys.badgeMode: defaultBadgeModeData as Any
        ])
    }

    // MARK: - Reading

    var remindersEnabled: Bool {
        _ = changeTick  // Trigger observation updates
        return userDefaults.bool(forKey: keyPrefix + Keys.remindersEnabled)
    }

    var reminderOffsets: [Int] {
        _ = changeTick  // Trigger observation updates
        let stored = userDefaults.array(forKey: keyPrefix + Keys.reminderOffsets) as? [Int]
            ?? Self.defaultReminderOffsets
        // Ensure at least one offset is always selected
        return stored.isEmpty ? Self.defaultReminderOffsets : stored
    }

    var reminderTime: DateComponents {
        _ = changeTick  // Trigger observation updates
        return DateComponents(
            hour: userDefaults.integer(forKey: keyPrefix + Keys.reminderTimeHour),
            minute: userDefaults.integer(forKey: keyPrefix + Keys.reminderTimeMinute)
        )
    }

    var digestEnabled: Bool {
        _ = changeTick  // Trigger observation updates
        return userDefaults.bool(forKey: keyPrefix + Keys.digestEnabled)
    }

    var digestLookaheadDays: Int {
        _ = changeTick  // Trigger observation updates
        let stored = userDefaults.integer(forKey: keyPrefix + Keys.digestLookaheadDays)
        return stored == 0 ? Self.defaultDigestLookaheadDays : stored
    }

    var digestTime: DateComponents {
        _ = changeTick  // Trigger observation updates
        return DateComponents(
            hour: userDefaults.integer(forKey: keyPrefix + Keys.digestTimeHour),
            minute: userDefaults.integer(forKey: keyPrefix + Keys.digestTimeMinute)
        )
    }

    var badgeMode: BadgeMode {
        _ = changeTick  // Trigger observation updates
        if let data = userDefaults.data(forKey: keyPrefix + Keys.badgeMode),
           let mode = try? JSONDecoder().decode(BadgeMode.self, from: data) {
            return mode
        }
        return Self.defaultBadgeMode
    }

    // MARK: - Writing

    func setRemindersEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: keyPrefix + Keys.remindersEnabled)
        triggerUpdate()
    }

    /// Sets enabled offsets. Must contain at least one value from availableOffsets.
    /// If empty array provided, falls back to default.
    func setReminderOffsets(_ offsets: [Int]) {
        let validOffsets = offsets.filter { Self.availableOffsets.contains($0) }
        let finalOffsets = validOffsets.isEmpty ? Self.defaultReminderOffsets : validOffsets
        userDefaults.set(finalOffsets, forKey: keyPrefix + Keys.reminderOffsets)
        triggerUpdate()
    }

    func setReminderTime(_ time: DateComponents) {
        userDefaults.set(time.hour ?? 9, forKey: keyPrefix + Keys.reminderTimeHour)
        userDefaults.set(time.minute ?? 0, forKey: keyPrefix + Keys.reminderTimeMinute)
        triggerUpdate()
    }

    func setDigestEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: keyPrefix + Keys.digestEnabled)
        triggerUpdate()
    }

    func setDigestLookaheadDays(_ days: Int) {
        userDefaults.set(days, forKey: keyPrefix + Keys.digestLookaheadDays)
        triggerUpdate()
    }

    func setDigestTime(_ time: DateComponents) {
        userDefaults.set(time.hour ?? 9, forKey: keyPrefix + Keys.digestTimeHour)
        userDefaults.set(time.minute ?? 0, forKey: keyPrefix + Keys.digestTimeMinute)
        triggerUpdate()
    }

    func setBadgeMode(_ mode: BadgeMode) {
        let data = try? JSONEncoder().encode(mode)
        userDefaults.set(data, forKey: keyPrefix + Keys.badgeMode)
        triggerUpdate()
    }

    /// Triggers observation update by modifying an observed property
    private func triggerUpdate() {
        changeTick &+= 1
    }
}
