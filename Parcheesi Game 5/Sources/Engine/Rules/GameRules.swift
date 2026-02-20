// GameRules.swift
// Core Parcheesi/Ludo rule engine — pure logic, no UI dependencies

import Foundation

/// Stateless rule engine for Parcheesi gameplay.
/// All methods are pure functions for testability.
enum GameRules {

    // MARK: - Board Constants

    /// Total squares on the main loop track
    static let mainTrackLength = 52

    /// Length of each player's home column
    static let homeColumnLength = 6

    /// A standard roll of 5 is required to enter the board
    static let entryRollRequired = 5

    /// Safe squares (shared blockade-immune positions) on the main track
    static let globalSafeSquares: Set<Int> = [0, 8, 13, 21, 26, 34, 39, 47]

    // MARK: - Entry Logic

    /// Returns true if a token can exit the yard with the given dice value.
    /// A token can enter on a 5 (either single die shows 5, or sum is 5).
    static func canEnterBoard(withDice dice: DiceResult) -> Bool {
        dice.die1 == 5 || dice.die2 == 5 || dice.total == 5
    }

    /// The board-entry value consumed when entering the board
    static func entryMoveValue(forDice dice: DiceResult) -> Int {
        if dice.die1 == 5 { return 5 }
        if dice.die2 == 5 { return 5 }
        if dice.total == 5 { return dice.die1 } // consume first die
        return 0
    }

    // MARK: - Move Validation

    /// Returns all legal moves for the current player given the dice result.
    static func legalMoves(for player: Player, dice: DiceResult, allPlayers: [Player]) -> [LegalMove] {
        var moves: [LegalMove] = []
        let moveValues = availableMoveValues(from: dice)

        for (tokenIndex, token) in player.tokens.enumerated() {
            guard !token.isFinished else { continue }

            for value in moveValues {
                if let move = validateMove(
                    player: player,
                    tokenIndex: tokenIndex,
                    moveValue: value,
                    allPlayers: allPlayers
                ) {
                    moves.append(move)
                }
            }
        }

        return moves
    }

    /// Decompose a dice result into available move values.
    /// On a double, player gets bonus moves (as per classic rules, 4 moves total).
    static func availableMoveValues(from dice: DiceResult) -> [Int] {
        if dice.isDouble {
            return [dice.die1, dice.die2, dice.die1, dice.die2]
        }
        return [dice.die1, dice.die2]
    }

    /// Validate and construct a single move, returning nil if illegal.
    static func validateMove(
        player: Player,
        tokenIndex: Int,
        moveValue: Int,
        allPlayers: [Player]
    ) -> LegalMove? {
        let token = player.tokens[tokenIndex]
        guard !token.isFinished else { return nil }

        switch token.state {
        case .inYard:
            guard moveValue == 5 else { return nil }
            let entry = entrySquare(for: player.color)
            // Entry square must not be doubly blocked by own tokens
            if isDoubleBlocked(position: entry, by: player.color, allPlayers: allPlayers) {
                return nil
            }
            let willCapture = hasOpponentToken(at: entry, excluding: player.color, allPlayers: allPlayers)
                && !isGlobalSafe(entry)
            return LegalMove(
                tokenIndex: tokenIndex,
                diceValue: moveValue,
                fromPosition: -1,
                toPosition: entry,
                moveType: willCapture ? .captureEnter : .enter
            )

        case .onBoard:
            let newPos = advancePosition(
                from: token.boardPosition,
                by: moveValue,
                color: player.color
            )
            guard let dest = newPos else { return nil }

            // Check if dest is double-blocked by opponents
            if isDoubleBlocked(position: dest, by: player.color, allPlayers: allPlayers) {
                return nil
            }

            let willCapture = hasOpponentToken(at: dest, excluding: player.color, allPlayers: allPlayers)
                && !isGlobalSafe(dest)

            return LegalMove(
                tokenIndex: tokenIndex,
                diceValue: moveValue,
                fromPosition: token.boardPosition,
                toPosition: dest,
                moveType: willCapture ? .capture : .normal
            )

        case .inHomeColumn:
            let newColPos = token.boardPosition + moveValue
            // Home column positions: mainTrackLength ... mainTrackLength+homeColumnLength-1
            let homeFinal = mainTrackLength + homeColumnLength - 1
            guard newColPos <= homeFinal else { return nil }
            let moveType: LegalMoveType = newColPos == homeFinal ? .finish : .homeColumn
            return LegalMove(
                tokenIndex: tokenIndex,
                diceValue: moveValue,
                fromPosition: token.boardPosition,
                toPosition: newColPos,
                moveType: moveType
            )

        case .finished:
            return nil
        }
    }

    // MARK: - Position Arithmetic

    /// The main-track square index where a player enters the board.
    static func entrySquare(for color: PlayerColor) -> Int {
        color.homeStartIndex
    }

    /// Advance a position by `steps` on the main track, transitioning to the
    /// home column when passing the color's home entry point.
    /// Returns nil if the move would overshoot past the home square.
    static func advancePosition(from pos: Int, by steps: Int, color: PlayerColor) -> Int? {
        let homeEntry = homeColumnEntrySquare(for: color) // square just before home column
        let homeEntryCircular = homeEntry

        // Calculate how many steps remain after reaching homeEntry
        let distToHomeEntry: Int
        if pos <= homeEntryCircular {
            distToHomeEntry = homeEntryCircular - pos
        } else {
            distToHomeEntry = (mainTrackLength - pos) + homeEntryCircular
        }

        if steps > distToHomeEntry {
            // We enter the home column
            let homeColumnSteps = steps - distToHomeEntry
            let colPos = mainTrackLength + homeColumnSteps - 1
            if colPos > mainTrackLength + homeColumnLength - 1 {
                return nil // Overshoot — cannot move
            }
            return colPos
        } else {
            // Stay on main track
            return (pos + steps) % mainTrackLength
        }
    }

    /// The last main-track square before the home column for each color.
    static func homeColumnEntrySquare(for color: PlayerColor) -> Int {
        switch color {
        case .red:    return 51
        case .blue:   return 12
        case .green:  return 25
        case .yellow: return 38
        }
    }

    // MARK: - Board Queries

    /// Returns true if `position` is a global safe square (immune to capture).
    static func isGlobalSafe(_ position: Int) -> Bool {
        globalSafeSquares.contains(position)
    }

    /// Returns true if two or more tokens of `ownerColor` occupy the position,
    /// making it a blockade that opponents cannot pass through or land on.
    static func isDoubleBlocked(position: Int, by ownerColor: PlayerColor, allPlayers: [Player]) -> Bool {
        // A blockade is formed by any TWO tokens of the SAME player on a square
        let opponentCount = allPlayers
            .filter { $0.color != ownerColor }
            .flatMap { $0.tokens }
            .filter { $0.state == .onBoard && $0.boardPosition == position }
            .count
        return opponentCount >= 2
    }

    /// Returns true if any opponent token occupies `position`.
    static func hasOpponentToken(at position: Int, excluding color: PlayerColor, allPlayers: [Player]) -> Bool {
        allPlayers
            .filter { $0.color != color }
            .flatMap { $0.tokens }
            .contains { $0.state == .onBoard && $0.boardPosition == position }
    }

    // MARK: - Apply Move

    /// Apply a validated move to a mutable game state copy.
    static func applyMove(_ move: LegalMove, to state: inout GameState) {
        var player = state.currentPlayer
        var token = player.tokens[move.tokenIndex]

        let captureBonus: Bool

        switch move.moveType {
        case .enter, .captureEnter:
            token.state = .onBoard
            token.boardPosition = move.toPosition
            captureBonus = move.moveType == .captureEnter

        case .normal, .capture:
            token.boardPosition = move.toPosition
            captureBonus = move.moveType == .capture

        case .homeColumn:
            token.state = .inHomeColumn
            token.boardPosition = move.toPosition
            captureBonus = false

        case .finish:
            token.state = .finished
            token.isFinished = true
            token.boardPosition = move.toPosition
            captureBonus = false
        }

        // Handle captures — send captured token back to yard
        if captureBonus {
            sendCapturedTokensHome(at: move.toPosition, excluding: player.color, state: &state)
            let event = CaptureEvent(
                capturing: player.color,
                captured: state.players
                    .first { $0.color != player.color && $0.tokens.contains { $0.boardPosition == move.toPosition } }?.color ?? .red,
                position: move.toPosition,
                turn: state.turnNumber
            )
            state.captureHistory.append(event)
        }

        player.tokens[move.tokenIndex] = token
        state.players[state.currentPlayerIndex] = player

        // Remove consumed move value
        if let idx = state.remainingMoves.firstIndex(of: move.diceValue) {
            state.remainingMoves.remove(at: idx)
        }

        state.updatedAt = Date()
    }

    // MARK: - Capture

    private static func sendCapturedTokensHome(at position: Int, excluding color: PlayerColor, state: inout GameState) {
        for pIdx in state.players.indices {
            guard state.players[pIdx].color != color else { continue }
            for tIdx in state.players[pIdx].tokens.indices {
                if state.players[pIdx].tokens[tIdx].state == .onBoard
                    && state.players[pIdx].tokens[tIdx].boardPosition == position {
                    state.players[pIdx].tokens[tIdx].state = .inYard
                    state.players[pIdx].tokens[tIdx].boardPosition = -1
                }
            }
        }
    }

    // MARK: - Turn Advancement

    /// Determine if the current player earns another roll (doubles or capture bonus).
    static func currentPlayerGetsAnotherTurn(dice: DiceResult, capturedThisTurn: Bool) -> Bool {
        return dice.isDouble || capturedThisTurn
    }

    /// Advance to the next player's turn.
    static func advanceTurn(state: inout GameState) {
        state.currentPlayerIndex = (state.currentPlayerIndex + 1) % state.players.count
        state.currentDice = nil
        state.remainingMoves = []
        state.phase = .rolling
        state.turnNumber += 1
        state.updatedAt = Date()
    }

    // MARK: - Win Condition

    static func checkWinner(state: GameState) -> Player? {
        state.players.first { $0.hasWon }
    }

    // MARK: - Forceful Moves

    /// If a player has no legal moves, their turn is skipped.
    static func hasAnyLegalMove(for player: Player, dice: DiceResult, allPlayers: [Player]) -> Bool {
        !legalMoves(for: player, dice: dice, allPlayers: allPlayers).isEmpty
    }
}

// MARK: - Legal Move

struct LegalMove: Identifiable {
    let id = UUID()
    let tokenIndex: Int
    let diceValue: Int
    let fromPosition: Int
    let toPosition: Int
    let moveType: LegalMoveType
}

enum LegalMoveType {
    case enter           // Token exits yard
    case captureEnter    // Token exits yard and captures
    case normal          // Regular token movement
    case capture         // Movement that captures an opponent
    case homeColumn      // Enters home column
    case finish          // Reaches home center
}
