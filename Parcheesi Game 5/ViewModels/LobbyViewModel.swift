// LobbyViewModel.swift
// Manages room creation, joining, matchmaking, and lobby state

import Foundation
import Combine

@MainActor
final class LobbyViewModel: ObservableObject {

    // MARK: - Published

    @Published var currentRoom: GameRoom?
    @Published var isSearchingForMatch: Bool = false
    @Published var matchmakingElapsed: Int = 0
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var navigateToGame: GameState?

    // MARK: - Dependencies

    private let networkService = MultiplayerNetworkService.shared
    private let authService = AuthService.shared
    private var matchmakingTimer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Create Private Room

    func createPrivateRoom(playerCount: Int) async {
        isLoading = true
        errorMessage = nil
        guard let userID = authService.currentUserID,
              let profile = await UserProfileService.shared.cachedProfile else {
            errorMessage = "Please sign in first."
            isLoading = false
            return
        }

        let host = Player(id: userID, displayName: profile.displayName, color: .red)
        let room = GameRoom(
            id: UUID().uuidString,
            hostPlayerID: userID,
            inviteCode: generateInviteCode(),
            mode: .privateRoom,
            players: [host],
            maxPlayers: playerCount,
            isPrivate: true,
            status: .waiting,
            createdAt: Date()
        )

        do {
            try await networkService.createRoom(room)
            currentRoom = room
            subscribeToRoom(roomID: room.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Join with Code

    func joinRoom(code: String) async {
        isLoading = true
        errorMessage = nil
        guard let userID = authService.currentUserID,
              let profile = await UserProfileService.shared.cachedProfile else {
            errorMessage = "Please sign in first."
            isLoading = false
            return
        }

        do {
            guard let room = try await networkService.findRoom(byCode: code.uppercased()) else {
                errorMessage = "Room not found. Check the code and try again."
                isLoading = false
                return
            }
            guard !room.isFull else {
                errorMessage = "That room is full."
                isLoading = false
                return
            }
            let joiningPlayer = Player(id: userID, displayName: profile.displayName, color: availableColor(in: room))
            try await networkService.joinRoom(roomID: room.id, player: joiningPlayer)
            subscribeToRoom(roomID: room.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Matchmaking

    func startMatchmaking(playerCount: Int) {
        guard !isSearchingForMatch else { return }
        isSearchingForMatch = true
        matchmakingElapsed = 0

        matchmakingTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.matchmakingElapsed += 1
            }

        Task {
            do {
                guard let userID = authService.currentUserID,
                      let profile = await UserProfileService.shared.cachedProfile else { return }
                let player = Player(id: userID, displayName: profile.displayName, color: .red)
                if let match = try await networkService.findOrCreateMatch(player: player, playerCount: playerCount) {
                    currentRoom = match
                    subscribeToRoom(roomID: match.id)
                }
            } catch {
                errorMessage = error.localizedDescription
                cancelMatchmaking()
            }
        }
    }

    func cancelMatchmaking() {
        matchmakingTimer?.cancel()
        isSearchingForMatch = false
        Task { try? await networkService.cancelMatchmaking() }
    }

    // MARK: - Start Game

    func startGame() async {
        guard let room = currentRoom, room.canStart else { return }
        let state = GameState(mode: room.mode, players: room.players)
        do {
            try await networkService.startGame(state, inRoom: room.id)
            navigateToGame = state
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Leave Room

    func leaveRoom() async {
        guard let room = currentRoom,
              let userID = authService.currentUserID else { return }
        try? await networkService.leaveRoom(roomID: room.id, playerID: userID)
        currentRoom = nil
    }

    // MARK: - Private Helpers

    private func subscribeToRoom(roomID: String) {
        networkService.observeRoom(roomID: roomID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] room in
                self?.currentRoom = room
                if room.status == .inProgress {
                    let state = GameState(mode: room.mode, players: room.players)
                    self?.navigateToGame = state
                }
            }
            .store(in: &cancellables)
    }

    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    private func availableColor(in room: GameRoom) -> PlayerColor {
        let usedColors = Set(room.players.map { $0.color })
        return PlayerColor.allCases.first { !usedColors.contains($0) } ?? .blue
    }
}
