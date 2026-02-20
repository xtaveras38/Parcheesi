// FirebaseService.swift
// Firebase Realtime Database, Firestore helpers, and core Firebase utilities

import Foundation
import FirebaseDatabase
import FirebaseFirestore

// MARK: - Database Reference Builder

enum FirebaseRef {

    private static let db = Database.database().reference()
    private static let store = Firestore.firestore()

    // MARK: - Realtime Database Refs (for low-latency game state)

    static func gameRef(_ gameID: String) -> DatabaseReference {
        db.child("games").child(gameID)
    }

    static func roomRef(_ roomID: String) -> DatabaseReference {
        db.child("rooms").child(roomID)
    }

    static func matchQueueRef() -> DatabaseReference {
        db.child("matchmaking_queue")
    }

    static func playerPresenceRef(_ userID: String) -> DatabaseReference {
        db.child("presence").child(userID)
    }

    // MARK: - Firestore Collection Refs (for persistent data)

    static func usersCollection() -> CollectionReference {
        store.collection("users")
    }

    static func userDocument(_ uid: String) -> DocumentReference {
        store.collection("users").document(uid)
    }

    static func friendRequestsCollection() -> CollectionReference {
        store.collection("friend_requests")
    }

    static func reportsCollection() -> CollectionReference {
        store.collection("reports")
    }

    static func leaderboardCollection() -> CollectionReference {
        store.collection("leaderboard")
    }
}

// MARK: - Firestore Codable Helpers

extension DocumentReference {
    /// Set a Codable value as the document data.
    func setData<T: Encodable>(_ value: T) async throws {
        let data = try Firestore.Encoder().encode(value)
        try await setData(data)
    }

    /// Decode the document as a Codable type.
    func getDocument<T: Decodable>(as type: T.Type) async throws -> T {
        let snapshot = try await getDocument()
        guard snapshot.exists else {
            throw FirestoreError.documentNotFound
        }
        return try snapshot.data(as: type)
    }

    /// Update specific fields.
    func updateData(_ fields: [String: Any]) async throws {
        try await updateData(fields as [AnyHashable: Any])
    }
}

enum FirestoreError: LocalizedError {
    case documentNotFound
    case encodingError
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .documentNotFound: return "The requested record was not found."
        case .encodingError: return "Data encoding failed."
        case .decodingError(let msg): return "Data decoding failed: \(msg)"
        }
    }
}
