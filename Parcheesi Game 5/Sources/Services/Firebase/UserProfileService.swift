// UserProfileService.swift
// Firestore-backed user profile CRUD, friends, and stats management

import Foundation
import FirebaseFirestore
import FirebaseStorage

final class UserProfileService {

    static let shared = UserProfileService()
    private init() {}

    private(set) var cachedProfile: UserProfile?
    private let encoder = Firestore.Encoder()
    private let decoder = Firestore.Decoder()

    // MARK: - Profile CRUD

    func createProfile(_ profile: UserProfile) async throws {
        try await FirebaseRef.userDocument(profile.id).setData(profile)
        cachedProfile = profile
    }

    func fetchProfile(uid: String) async throws -> UserProfile {
        let profile = try await FirebaseRef.userDocument(uid).getDocument(as: UserProfile.self)
        cachedProfile = profile
        return profile
    }

    func profileExists(uid: String) async -> Bool {
        let snapshot = try? await FirebaseRef.userDocument(uid).getDocument()
        return snapshot?.exists ?? false
    }

    func updateField(uid: String, key: String, value: Any) async throws {
        try await FirebaseRef.userDocument(uid).updateData([key: value])
        // Update cache
        if var cached = cachedProfile, cached.id == uid {
            // Reflection-free approach: re-fetch for simplicity
            // In production, use a property wrapper or dictionary-based update
            cachedProfile = try await fetchProfile(uid: uid)
        }
    }

    // MARK: - Batch Fetch

    func fetchUsers(ids: [String]) async throws -> [UserProfile] {
        guard !ids.isEmpty else { return [] }
        var users: [UserProfile] = []
        // Firestore in queries support up to 10 items; chunk for safety
        for chunk in ids.chunked(into: 10) {
            let snapshot = try await FirebaseRef.usersCollection()
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            let chunkUsers = try snapshot.documents.compactMap { doc in
                try doc.data(as: UserProfile.self)
            }
            users.append(contentsOf: chunkUsers)
        }
        return users
    }

    // MARK: - Currency

    func addCoins(uid: String, amount: Int) async throws {
        try await FirebaseRef.userDocument(uid)
            .updateData(["coins": FieldValue.increment(Int64(amount))])
    }

    func addGems(uid: String, amount: Int) async throws {
        try await FirebaseRef.userDocument(uid)
            .updateData(["gems": FieldValue.increment(Int64(amount))])
    }

    func deductCoins(uid: String, amount: Int) async throws {
        try await FirebaseRef.userDocument(uid)
            .updateData(["coins": FieldValue.increment(Int64(-amount))])
    }

    func setPremium(uid: String, expiresAt: Date) async throws {
        try await FirebaseRef.userDocument(uid).updateData([
            "isPremium": true,
            "premiumExpiresAt": Timestamp(date: expiresAt)
        ])
    }

    // MARK: - XP & Stats

    func addXP(uid: String, amount: Int) async throws {
        try await FirebaseRef.userDocument(uid)
            .updateData(["xp": FieldValue.increment(Int64(amount))])
        // Recalculate level server-side via Cloud Function (see firebase/functions/)
    }

    func updateStats(uid: String, stats: GameStats) async throws {
        let data = try encoder.encode(stats)
        try await FirebaseRef.userDocument(uid).updateData(["stats": data])
    }

    // MARK: - Friends

    func sendFriendRequest(_ request: FriendRequest) async throws {
        try await FirebaseRef.friendRequestsCollection()
            .document(request.id)
            .setData(request)
    }

    func fetchPendingFriendRequests(for uid: String) async throws -> [FriendRequest] {
        let snapshot = try await FirebaseRef.friendRequestsCollection()
            .whereField("receiverID", isEqualTo: uid)
            .whereField("status", isEqualTo: FriendRequest.FriendRequestStatus.pending.rawValue)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: FriendRequest.self) }
    }

    func acceptFriendRequest(_ request: FriendRequest, currentUserID: String) async throws {
        let batch = Firestore.firestore().batch()

        // Update request status
        let requestRef = FirebaseRef.friendRequestsCollection().document(request.id)
        batch.updateData(["status": FriendRequest.FriendRequestStatus.accepted.rawValue], forDocument: requestRef)

        // Add each user to the other's friends list
        batch.updateData(
            ["friendIDs": FieldValue.arrayUnion([request.senderID])],
            forDocument: FirebaseRef.userDocument(currentUserID)
        )
        batch.updateData(
            ["friendIDs": FieldValue.arrayUnion([currentUserID])],
            forDocument: FirebaseRef.userDocument(request.senderID)
        )

        try await batch.commit()
    }

    func declineFriendRequest(_ request: FriendRequest) async throws {
        try await FirebaseRef.friendRequestsCollection()
            .document(request.id)
            .updateData(["status": FriendRequest.FriendRequestStatus.declined.rawValue])
    }

    func removeFriend(currentUserID: String, friendID: String) async throws {
        let batch = Firestore.firestore().batch()
        batch.updateData(
            ["friendIDs": FieldValue.arrayRemove([friendID])],
            forDocument: FirebaseRef.userDocument(currentUserID)
        )
        batch.updateData(
            ["friendIDs": FieldValue.arrayRemove([currentUserID])],
            forDocument: FirebaseRef.userDocument(friendID)
        )
        try await batch.commit()
    }

    // MARK: - Reports

    func submitReport(_ report: UserReport) async throws {
        try await FirebaseRef.reportsCollection()
            .document(report.id)
            .setData(report)
    }
}

// MARK: - Array Chunking Helper

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
