// GameModels.swift
// Core data models for the Parcheesi board game

import Foundation
import SwiftUI

// MARK: - Player Color

/// The four player colors used in the game
enum PlayerColor: String, Codable, CaseIterable, Identifiable {
    case red, blue, green, yellow

    var id: String { rawValue }

    var swiftUIColor: Color {
        switch self {
        case .red:    return Color(red: 0.85, green: 0.18, blue: 0.18)
        case .blue:   return Color(red: 0.18, green: 0.38, blue: 0.85)
        case .green:  return Color(red: 0.15, green: 0.72, blue: 0.35)
        case .yellow: return Color(red: 0.95, green: 0.78, blue: 0.10)
        }
    }

    var homeStartIndex: Int {
        switch self {
        case .red:    return 0
        case .blue:   return 13
        case .green:  return 26
        case .yellow: return 39
        }
    }

    /// Safe squares for this color (column entries)
    var safeSquares: [Int] {
        let start = homeStartIndex
        return [start, (start + 8) % 52]
    }
}

// MARK: - Token

/// Represents a single game token belonging to a player
struct Token: Identifiable, Codable, Equatable {
    let id: UUID
    let playerColor: PlayerColor
    var state: TokenState
    var boardPosition: Int     // -1 = home yard, 0-51 = main track, 52-57 = home column
    var isFinished: Bool

    init(playerColor: PlayerColor) {
        self.id = UUID()
        self.playerColor = playerColor
        self.state = .inYard
        self.boardPosition = -1
        self.isFinished = false
    }

    /// Absolute position on the unified 52-square track
    var absolutePosition: Int {
        guard state == .onBoard else { return -1 }
        return boardPosition
    }
}

// MARK: - Token State

enum TokenState: String, Codable {
    case inYard      // Not yet entered the board
    case onBoard     // On the main 52-square track
    case inHomeColumn // On the color-specific home column (6 squares)
    case finished    // Reached the center home
}

// MARK: - Player

struct Player: Identifiable, Codable {
    let id: String           // Firebase UID or local UUID
    var displayName: String
    var avatarURL: String?
    var color: PlayerColor
    var tokens: [Token]
    var isAI: Bool
    var aiDifficulty: AIDifficulty?
    var xp: Int
    var level: Int

    init(
        id: String = UUID().uuidString,
        displayName: String,
        color: PlayerColor,
        isAI: Bool = false,
        aiDifficulty: AIDifficulty? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.color = color
        self.tokens = (0..<4).map { _ in Token(playerColor: color) }
        self.isAI = isAI
        self.aiDifficulty = aiDifficulty
        self.xp = 0
        self.level = 1
    }

    var finishedTokenCount: Int {
        tokens.filter { $0.isFinished }.count
    }

    var hasWon: Bool {
        finishedTokenCount == 4
    }

    var activeTokens: [Token] {
        tokens.filter { !$0.isFinished && $0.state == .onBoard }
    }
}

// MARK: - Dice Result

struct DiceResult: Codable, Equatable {
    let die1: Int
    let die2: Int
    var isDouble: Bool { die1 == die2 }
    var total: Int { die1 + die2 }

    static func roll() -> DiceResult {
        DiceResult(
            die1: Int.random(in: 1...6),
            die2: Int.random(in: 1...6)
        )
    }
}

// MARK: - Game Mode

enum GameMode: String, Codable, CaseIterable {
    case localPassAndPlay = "local"
    case onlineMultiplayer = "online"
    case vsAI = "ai"
    case privateRoom = "private"
}

// MARK: - AI Difficulty

enum AIDifficulty: String, Codable, CaseIterable {
    case easy
    case medium
    case hard
}

// MARK: - Game Phase

enum GamePhase: String, Codable {
    case waiting      // Waiting for players
    case rolling      // Current player rolling dice
    case moving       // Current player selecting token to move
    case animating    // Animation in progress
    case finished     // Game over
}

// MARK: - Game State

struct GameState: Codable {
    var gameID: String
    var mode: GameMode
    var players: [Player]
    var currentPlayerIndex: Int
    var phase: GamePhase
    var currentDice: DiceResult?
    var remainingMoves: [Int]   // Pending move values to apply
    var turnNumber: Int
    var captureHistory: [CaptureEvent]
    var chatMessages: [ChatMessage]
    var createdAt: Date
    var updatedAt: Date
    var roomCode: String?

    init(mode: GameMode, players: [Player]) {
        self.gameID = UUID().uuidString
        self.mode = mode
        self.players = players
        self.currentPlayerIndex = 0
        self.phase = .rolling
        self.currentDice = nil
        self.remainingMoves = []
        self.turnNumber = 1
        self.captureHistory = []
        self.chatMessages = []
        self.createdAt = Date()
        self.updatedAt = Date()
        self.roomCode = nil
    }

    var currentPlayer: Player {
        get { players[currentPlayerIndex] }
        set { players[currentPlayerIndex] = newValue }
    }
}

// MARK: - Capture Event

struct CaptureEvent: Codable, Identifiable {
    let id: UUID
    let capturingPlayerColor: PlayerColor
    let capturedPlayerColor: PlayerColor
    let position: Int
    let turnNumber: Int

    init(capturing: PlayerColor, captured: PlayerColor, position: Int, turn: Int) {
        self.id = UUID()
        self.capturingPlayerColor = capturing
        self.capturedPlayerColor = captured
        self.position = position
        self.turnNumber = turn
    }
}

// MARK: - Chat Message

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let playerID: String
    let playerName: String
    let playerColor: PlayerColor
    let content: String
    let timestamp: Date
    let isEmoji: Bool

    init(playerID: String, playerName: String, playerColor: PlayerColor, content: String) {
        self.id = UUID()
        self.playerID = playerID
        self.playerName = playerName
        self.playerColor = playerColor
        self.content = content
        self.timestamp = Date()
        self.isEmoji = content.unicodeScalars.allSatisfy { $0.properties.isEmoji }
    }
}

// MARK: - Room

struct GameRoom: Codable, Identifiable {
    var id: String
    var hostPlayerID: String
    var inviteCode: String
    var mode: GameMode
    var players: [Player]
    var maxPlayers: Int
    var isPrivate: Bool
    var status: RoomStatus
    var createdAt: Date

    enum RoomStatus: String, Codable {
        case waiting, starting, inProgress, finished
    }

    var isFull: Bool { players.count >= maxPlayers }
    var canStart: Bool { players.count >= 2 && status == .waiting }
}

// MARK: - Move

/// A validated move to be applied to the game state
struct GameMove: Codable {
    let playerID: String
    let tokenID: UUID
    let diceValue: Int
    let fromPosition: Int
    let toPosition: Int
    let causedCapture: Bool
}
