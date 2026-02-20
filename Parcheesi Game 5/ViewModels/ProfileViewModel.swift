// ProfileViewModel.swift
// Manages user profile, stats, friends, avatar, and theme selection

import Foundation
import Combine
import PhotosUI
import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {

    // MARK: - Published

    @Published var profile: UserProfile?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var friends: [UserProfile] = []
    @Published var pendingRequests: [FriendRequest] = []
    @Published var selectedPhotoItem: PhotosPickerItem?

    // MARK: - Dependencies

    private let userService = UserProfileService.shared
    private let storageService = StorageService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Load Profile

    func loadProfile(userID: String) async {
        isLoading = true
        do {
            profile = try await userService.fetchProfile(uid: userID)
            await loadFriends()
            await loadPendingRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Update Display Name

    func updateDisplayName(_ name: String) async {
        guard let uid = profile?.id else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty && trimmed.count <= 20 else {
            errorMessage = "Name must be 1–20 characters."
            return
        }
        do {
            try await userService.updateField(uid: uid, key: "displayName", value: trimmed)
            profile?.displayName = trimmed
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Avatar Upload

    func uploadAvatar(from item: PhotosPickerItem) async {
        guard let uid = profile?.id else { return }
        isLoading = true
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Failed to load image."
                isLoading = false
                return
            }
            let url = try await storageService.uploadAvatar(uid: uid, imageData: data)
            try await userService.updateField(uid: uid, key: "avatarURL", value: url.absoluteString)
            profile?.avatarURL = url.absoluteString
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Avatar & Theme Selection

    func selectAvatar(id: String) async {
        guard let uid = profile?.id else { return }
        guard profile?.unlockedAvatarIDs.contains(id) == true else {
            errorMessage = "Purchase this avatar first."
            return
        }
        try? await userService.updateField(uid: uid, key: "selectedAvatarID", value: id)
        profile?.selectedAvatarID = id
    }

    func selectTheme(id: String) async {
        guard let uid = profile?.id else { return }
        guard profile?.unlockedThemeIDs.contains(id) == true else {
            errorMessage = "Purchase this theme first."
            return
        }
        try? await userService.updateField(uid: uid, key: "selectedThemeID", value: id)
        profile?.selectedThemeID = id
    }

    // MARK: - Friends

    func loadFriends() async {
        guard let profile else { return }
        do {
            friends = try await userService.fetchUsers(ids: profile.friendIDs)
        } catch {
            print("[ProfileViewModel] Friends load error: \(error)")
        }
    }

    func sendFriendRequest(toUserID: String) async {
        guard let uid = profile?.id, let name = profile?.displayName else { return }
        let request = FriendRequest(
            id: UUID().uuidString,
            senderID: uid,
            senderName: name,
            senderAvatarURL: profile?.avatarURL,
            receiverID: toUserID,
            status: .pending,
            sentAt: Date()
        )
        do {
            try await userService.sendFriendRequest(request)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptFriendRequest(_ request: FriendRequest) async {
        guard let uid = profile?.id else { return }
        do {
            try await userService.acceptFriendRequest(request, currentUserID: uid)
            profile?.friendIDs.append(request.senderID)
            pendingRequests.removeAll { $0.id == request.id }
            await loadFriends()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func declineFriendRequest(_ request: FriendRequest) async {
        do {
            try await userService.declineFriendRequest(request)
            pendingRequests.removeAll { $0.id == request.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeFriend(userID: String) async {
        guard let uid = profile?.id else { return }
        do {
            try await userService.removeFriend(currentUserID: uid, friendID: userID)
            profile?.friendIDs.removeAll { $0 == userID }
            friends.removeAll { $0.id == userID }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPendingRequests() async {
        guard let uid = profile?.id else { return }
        do {
            pendingRequests = try await userService.fetchPendingFriendRequests(for: uid)
        } catch {
            print("[ProfileViewModel] Friend requests load error: \(error)")
        }
    }

    // MARK: - Report User

    func reportUser(targetID: String, reason: UserReport.ReportReason, description: String, gameID: String?) async {
        guard let uid = profile?.id else { return }
        let report = UserReport(
            id: UUID().uuidString,
            reporterID: uid,
            reportedID: targetID,
            gameID: gameID,
            reason: reason,
            description: description,
            createdAt: Date()
        )
        try? await userService.submitReport(report)
    }

    // MARK: - XP Progress

    var xpProgressPercent: Double {
        guard let profile else { return 0 }
        let currentLevelXP = XPSystem.xpRequired(forLevel: profile.level)
        let nextLevelXP = XPSystem.xpRequired(forLevel: profile.level + 1)
        let range = nextLevelXP - currentLevelXP
        guard range > 0 else { return 1 }
        return Double(profile.xp - currentLevelXP) / Double(range)
    }
}
