//
//  UNAuthorizationStatus+Authorization.swift
//  Billo
//
//  Created by Jiri Urbasek on 12/30/25.
//

import UserNotifications

extension UNAuthorizationStatus {
    nonisolated var isEffectivelyAuthorizedForReminders: Bool {
        switch self {
        case .authorized, .provisional:
            return true
#if os(iOS)
        case .ephemeral:
            return true
#endif
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }
}
