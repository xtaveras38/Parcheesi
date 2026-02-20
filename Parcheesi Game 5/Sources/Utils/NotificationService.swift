// NotificationService.swift
// Push notification registration, routing, and local notifications

import Foundation
import FirebaseMessaging
import UserNotifications
import FirebaseFirestore

final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    // MARK: - FCM Token

    func updateFCMToken(_ token: String) {
        guard let uid = AuthService.shared.currentUserID else { return }
        Task {
            try? await UserProfileService.shared.updateField(uid: uid, key: "fcmToken", value: token)
        }
    }

    // MARK: - Local Notifications

    func scheduleMatchInviteNotification(senderName: String, roomCode: String) {
        let content = UNMutableNotificationContent()
        content.title = "Game Invitation!"
        content.body = "\(senderName) invited you to play. Code: \(roomCode)"
        content.sound = .default
        content.userInfo = ["type": "room_invite", "code": roomCode]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "invite_\(roomCode)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleTurnReminder(playerName: String, gameID: String) {
        let content = UNMutableNotificationContent()
        content.title = "Your Turn!"
        content.body = "It's time to make your move in Parcheesi Quest."
        content.sound = .default
        content.userInfo = ["type": "turn_reminder", "gameID": gameID]
        content.badge = 1

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
        let request = UNNotificationRequest(
            identifier: "turn_\(gameID)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelTurnReminder(gameID: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["turn_\(gameID)"])
    }

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}

// MARK: - Notification Router

final class NotificationRouter {

    static let shared = NotificationRouter()
    private init() {}

    func route(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }
        switch type {
        case "room_invite":
            if let code = userInfo["code"] as? String {
                NotificationCenter.default.post(
                    name: .init("OpenRoomInvite"),
                    object: nil,
                    userInfo: ["code": code]
                )
            }
        case "turn_reminder":
            if let gameID = userInfo["gameID"] as? String {
                NotificationCenter.default.post(
                    name: .init("OpenGame"),
                    object: nil,
                    userInfo: ["gameID": gameID]
                )
            }
        case "friend_request":
            NotificationCenter.default.post(name: .init("OpenFriendRequests"), object: nil)
        default:
            break
        }
    }
}
