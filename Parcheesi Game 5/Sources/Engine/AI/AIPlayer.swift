// AIPlayer.swift
// AI engine with Easy / Medium / Hard difficulty levels

import Foundation

/// The AI decision engine. All methods are synchronous and pure;
/// the caller is responsible for dispatching to a background queue.
struct AIPlayer {

    let difficulty: AIDifficulty

    // MARK: - Move Selection Entry Point

    /// Returns the move the AI chooses, or nil if no moves are available.
    func chooseMove(
        for player: Player,
        dice: DiceResult,
        gameState: GameState
    ) -> LegalMove? {
        let moves = GameRules.legalMoves(for: player, dice: dice, allPlayers: gameState.players)
        guard !moves.isEmpty else { return nil }

        switch difficulty {
        case .easy:   return easyStrategy(moves: moves, player: player, state: gameState)
        case .medium: return mediumStrategy(moves: moves, player: player, state: gameState)
        case .hard:   return hardStrategy(moves: moves, player: player, state: gameState)
        }
    }

    // MARK: - Easy Strategy
    // Picks a random valid move. Great for beginners.

    private func easyStrategy(moves: [LegalMove], player: Player, state: GameState) -> LegalMove {
        return moves.randomElement()!
    }

    // MARK: - Medium Strategy
    // Prefers captures and entering the board; avoids predictable patterns.

    private func mediumStrategy(moves: [LegalMove], player: Player, state: GameState) -> LegalMove {
        // Priority: finish > capture > enter board > advance furthest token
        if let finishMove = moves.first(where: { $0.moveType == .finish }) {
            return finishMove
        }
        if let captureMove = moves.first(where: { $0.moveType == .capture || $0.moveType == .captureEnter }) {
            return captureMove
        }
        if let enterMove = moves.first(where: { $0.moveType == .enter }) {
            return enterMove
        }
        // Advance the token that is furthest along
        return moves.max(by: { $0.fromPosition < $1.fromPosition }) ?? moves[0]
    }

    // MARK: - Hard Strategy
    // Uses a heuristic scoring function to evaluate all moves.

    private func hardStrategy(moves: [LegalMove], player: Player, state: GameState) -> LegalMove {
        var bestMove = moves[0]
        var bestScore = Int.min

        for move in moves {
            var simulatedState = state
            GameRules.applyMove(move, to: &simulatedState)
            let score = evaluateState(simulatedState, forPlayer: player)
            if score > bestScore {
                bestScore = score
                bestMove = move
            }
        }
        return bestMove
    }

    // MARK: - Heuristic Evaluation

    /// Score the game state from the perspective of `player`. Higher is better.
    private func evaluateState(_ state: GameState, forPlayer player: Player) -> Int {
        guard let currentPlayer = state.players.first(where: { $0.id == player.id }) else {
            return 0
        }

        var score = 0

        for token in currentPlayer.tokens {
            switch token.state {
            case .inYard:
                score -= 50  // Tokens in yard are penalized
            case .onBoard:
                score += progressScore(forPosition: token.boardPosition, color: player.color)
                score += safetyScore(forPosition: token.boardPosition, color: player.color)
            case .inHomeColumn:
                score += 200 + token.boardPosition * 20
            case .finished:
                score += 500
            }
        }

        // Penalize opponents' progress
        for opponent in state.players where opponent.id != player.id {
            for token in opponent.tokens where token.state == .onBoard {
                score -= progressScore(forPosition: token.boardPosition, color: opponent.color) / 3
            }
            score -= opponent.finishedTokenCount * 300
        }

        return score
    }

    /// Score based on how far a token has progressed (higher = closer to home).
    private func progressScore(forPosition pos: Int, color: PlayerColor) -> Int {
        let entry = GameRules.entrySquare(for: color)
        let steps: Int
        if pos >= entry {
            steps = pos - entry
        } else {
            steps = GameRules.mainTrackLength - entry + pos
        }
        return steps * 5
    }

    /// Bonus for being on a safe square; penalty for being exposed to capture.
    private func safetyScore(forPosition pos: Int, color: PlayerColor) -> Int {
        if GameRules.isGlobalSafe(pos) { return 20 }
        return -5  // Small penalty for being on an unsafe square
    }
}

// MARK: - AI Turn Orchestrator

/// Manages the async execution of AI turns with a human-like thinking delay.
final class AITurnOrchestrator {

    static let shared = AITurnOrchestrator()
    private init() {}

    /// Execute an AI turn and call completion with the chosen move.
    func executeTurn(
        player: Player,
        dice: DiceResult,
        state: GameState,
        completion: @escaping (LegalMove?) -> Void
    ) {
        let difficulty = player.aiDifficulty ?? .easy
        let ai = AIPlayer(difficulty: difficulty)
        let delayMs = FeatureFlags.shared.aiThinkingDelayMs

        DispatchQueue.global(qos: .userInteractive).async {
            let move = ai.chooseMove(for: player, dice: dice, gameState: state)
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs)) {
                completion(move)
            }
        }
    }
}
