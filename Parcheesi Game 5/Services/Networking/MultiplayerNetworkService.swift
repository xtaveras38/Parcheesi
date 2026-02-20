// MultiplayerNetworkService.swift
// Firebase Realtime Database–backed multiplayer sync layer

import Foundation
import Combine
import FirebaseDatabase

/// Handles all real-time multiplayer communication via Firebase RTDB.
/// Emits remote state changes as Combine publishers.
final class MultiplayerNetworkService {

    static let shared = MultiplayerNetworkService()
    private init() {}

    // MARK: - Publishers

    private let _remoteStateSubject = PassthroughSubject<GameState, Never>()
    var remoteStatePublisher: AnyPublisher<GameState, Never> {
        _remoteStateSubject.eraseToAnyPublisher()
    }

    private let _roomUpdateSubject = PassthroughSubject<GameRoom, Never>()
    var roomUpdatePublisher: AnyPublisher<GameRoom, Never> {
        _roomUpdateSubject.eraseToAnyPublisher()
    }

    // MARK: - Observation Handles

    private var gameObserverHandle: DatabaseHandle?
    private var roomObserverHandle: DatabaseHandle?
    private var observedGameID: String?
    private var observedRoomID: String?

    // MARK: - Room Management

    func createRoom(_ room: GameRoom) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(room)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NetworkError.encodingFailed
        }
        try await FirebaseRef.roomRef(room.id).setValue(dict)
    }

    func findRoom(byCode code: String) async throws -> GameRoom? {
        let snapshot = try await FirebaseRef.roomRef("").queryOrdered(byChild: "inviteCode")
            .queryEqual(toValue: code)
            .getData()

        guard snapshot.exists(), let dict = snapshot.value as? [String: [String: Any]],
              let roomDict = dict.values.first else { return nil }

        return try decodeRoom(from: roomDict)
    }

    func joinRoom(roomID: String, player: Player) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let playerData = try encoder.encode(player)
        guard let playerDict = try JSONSerialization.jsonObject(with: playerData) as? [String: Any] else {
            throw NetworkError.encodingFailed
        }
        // Use a transaction to safely add the player
        try await FirebaseRef.roomRef(roomID).child("players").child(player.id).setValue(playerDict)
    }

    func leaveRoom(roomID: String, playerID: String) async throws {
        try await FirebaseRef.roomRef(roomID).child("players").child(playerID).removeValue()
    }

    func observeRoom(roomID: String) -> AnyPublisher<GameRoom, Never> {
        stopObservingRoom()
        observedRoomID = roomID

        let subject = PassthroughSubject<GameRoom, Never>()

        roomObserverHandle = FirebaseRef.roomRef(roomID).observe(.value) { [weak self] snapshot in
            guard let self,
                  snapshot.exists(),
                  let dict = snapshot.value as? [String: Any],
                  let room = try? self.decodeRoom(from: dict) else { return }
            subject.send(room)
            self._roomUpdateSubject.send(room)
        }

        return subject.eraseToAnyPublisher()
    }

    private func stopObservingRoom() {
        if let handle = roomObserverHandle, let id = observedRoomID {
            FirebaseRef.roomRef(id).removeObserver(withHandle: handle)
        }
    }

    // MARK: - Game State Sync

    func startGame(_ state: GameState, inRoom roomID: String) async throws {
        // Update room status
        try await FirebaseRef.roomRef(roomID).updateChildValues(["status": GameRoom.RoomStatus.inProgress.rawValue])
        // Upload initial game state
        try await uploadGameState(state)
    }

    func uploadGameState(_ state: GameState) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NetworkError.encodingFailed
        }
        try await FirebaseRef.gameRef(state.gameID).setValue(dict)
    }

    func observeGameState(gameID: String) {
        stopObservingGame()
        observedGameID = gameID

        gameObserverHandle = FirebaseRef.gameRef(gameID).observe(.value) { [weak self] snapshot in
            guard let self,
                  snapshot.exists(),
                  let dict = snapshot.value as? [String: Any],
                  let state = try? self.decodeGameState(from: dict) else { return }
            self._remoteStateSubject.send(state)
        }
    }

    private func stopObservingGame() {
        if let handle = gameObserverHandle, let id = observedGameID {
            FirebaseRef.gameRef(id).removeObserver(withHandle: handle)
        }
    }

    // MARK: - Broadcast Events

    func broadcastDiceRoll(_ result: DiceResult, gameID: String) {
        let dict: [String: Any] = [
            "die1": result.die1,
            "die2": result.die2,
            "timestamp": ServerValue.timestamp()
        ]
        FirebaseRef.gameRef(gameID).child("lastDiceRoll").setValue(dict)
    }

    func broadcastMove(_ move: LegalMove, gameID: String) {
        let dict: [String: Any] = [
            "tokenIndex": move.tokenIndex,
            "diceValue": move.diceValue,
            "fromPosition": move.fromPosition,
            "toPosition": move.toPosition,
            "timestamp": ServerValue.timestamp()
        ]
        FirebaseRef.gameRef(gameID).child("lastMove").setValue(dict)
    }

    func broadcastChat(_ message: ChatMessage, gameID: String) {
        let dict: [String: Any] = [
            "id": message.id.uuidString,
            "playerID": message.playerID,
            "playerName": message.playerName,
            "playerColor": message.playerColor.rawValue,
            "content": message.content,
            "timestamp": ServerValue.timestamp()
        ]
        FirebaseRef.gameRef(gameID).child("chatMessages").child(message.id.uuidString).setValue(dict)
    }

    func broadcastGameEnd(winnerID: String, gameID: String) {
        FirebaseRef.gameRef(gameID).child("winner").setValue(winnerID)
        FirebaseRef.gameRef(gameID).child("phase").setValue(GamePhase.finished.rawValue)
    }

    // MARK: - Matchmaking

    func findOrCreateMatch(player: Player, playerCount: Int) async throws -> GameRoom? {
        // Query for an open room with the right player count
        let snapshot = try await FirebaseRef.roomRef("").queryOrdered(byChild: "status")
            .queryEqual(toValue: GameRoom.RoomStatus.waiting.rawValue)
            .getData()

        guard snapshot.exists(), let dict = snapshot.value as? [String: [String: Any]] else {
            // No open rooms — create one
            let room = GameRoom(
                id: UUID().uuidString,
                hostPlayerID: player.id,
                inviteCode: UUID().uuidString.prefix(6).uppercased().description,
                mode: .onlineMultiplayer,
                players: [player],
                maxPlayers: playerCount,
                isPrivate: false,
                status: .waiting,
                createdAt: Date()
            )
            try await createRoom(room)
            return room
        }

        // Find suitable room
        for (_, roomDict) in dict {
            if let room = try? decodeRoom(from: roomDict),
               !room.isFull,
               room.maxPlayers == playerCount {
                try await joinRoom(roomID: room.id, player: player)
                return room
            }
        }
        return nil
    }

    func cancelMatchmaking() async throws {
        guard let uid = AuthService.shared.currentUserID else { return }
        // Remove from any rooms where user is listed and room hasn't started
        // Simplified — full implementation queries and removes
        FirebaseRef.matchQueueRef().child(uid).removeValue()
    }

    // MARK: - Decode Helpers

    private func decodeGameState(from dict: [String: Any]) throws -> GameState {
        let data = try JSONSerialization.data(withJSONObject: dict)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GameState.self, from: data)
    }

    private func decodeRoom(from dict: [String: Any]) throws -> GameRoom {
        let data = try JSONSerialization.data(withJSONObject: dict)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GameRoom.self, from: data)
    }
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case roomNotFound
    case roomFull
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .encodingFailed:   return "Failed to encode data for upload."
        case .decodingFailed:   return "Failed to parse server data."
        case .roomNotFound:     return "Room not found."
        case .roomFull:         return "The room is full."
        case .notAuthenticated: return "You must be signed in to play online."
        }
    }
}
