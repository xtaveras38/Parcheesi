// GameViewModel.swift
// Primary ViewModel for in-game screen. Orchestrates rules, animations, AI, networking.

import Foundation
import Combine
import SwiftUI

@MainActor
final class GameViewModel: ObservableObject {

    // MARK: - Published State

    @Published var gameState: GameState
    @Published var legalMoves: [LegalMove] = []
    @Published var selectedTokenIndex: Int? = nil
    @Published var animatingTokenID: UUID? = nil
    @Published var diceAnimating: Bool = false
    @Published var isMyTurn: Bool = true
    @Published var winner: Player? = nil
    @Published var showWinScreen: Bool = false
    @Published var turnTimeRemaining: Int = 60
    @Published var showCaptureFlash: PlayerColor? = nil
    @Published var toastMessage: String? = nil

    // MARK: - Dependencies

    private let networkService: MultiplayerNetworkService?
    private let audioService = AudioService.shared
    private let hapticService = HapticService.shared
    private let analyticsService = AnalyticsService.shared

    private var turnTimer: AnyCancellable?
    private var networkCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(gameState: GameState, networkService: MultiplayerNetworkService? = nil) {
        self.gameState = gameState
        self.networkService = networkService
        GameStateManager.shared.currentGameState = gameState
        subscribeToNetwork()
        startTurnTimerIfNeeded()
    }

    // MARK: - Dice Rolling

    func rollDice() {
        guard gameState.phase == .rolling, isMyTurn else { return }
        diceAnimating = true

        // Play dice sound and haptic
        audioService.play(.diceRoll)
        hapticService.trigger(.diceRoll)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            let result = DiceResult.roll()
            self.gameState.currentDice = result
            self.gameState.remainingMoves = GameRules.availableMoveValues(from: result)
            self.diceAnimating = false
            self.gameState.phase = .moving

            // Calculate legal moves
            self.legalMoves = GameRules.legalMoves(
                for: self.gameState.currentPlayer,
                dice: result,
                allPlayers: self.gameState.players
            )

            if self.legalMoves.isEmpty {
                self.showToast("No moves available — skipping turn")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.advanceTurn()
                }
            }

            // Broadcast to network if in online mode
            self.networkService?.broadcastDiceRoll(result, gameID: self.gameState.gameID)
            self.analyticsService.track(event: "dice_rolled", properties: [
                "die1": result.die1, "die2": result.die2, "is_double": result.isDouble
            ])

            // Check if AI turn
            if self.gameState.currentPlayer.isAI {
                self.executeAITurn()
            }
        }
    }

    // MARK: - Token Selection & Move

    func selectToken(at index: Int) {
        guard gameState.phase == .moving else { return }
        guard !gameState.currentPlayer.tokens[index].isFinished else { return }
        selectedTokenIndex = index
    }

    func executeMove(_ move: LegalMove) {
        guard gameState.phase == .moving else { return }
        guard let dice = gameState.currentDice else { return }

        gameState.phase = .animating
        animatingTokenID = gameState.currentPlayer.tokens[move.tokenIndex].id
        selectedTokenIndex = nil

        let causedCapture = move.moveType == .capture || move.moveType == .captureEnter

        // Apply the move
        GameRules.applyMove(move, to: &gameState)

        // Sound & haptics
        audioService.play(causedCapture ? .capture : .tokenMove)
        hapticService.trigger(causedCapture ? .capture : .tokenMove)

        if causedCapture {
            if let capturedColor = gameState.players
                .first(where: { $0.color != gameState.currentPlayer.color
                    && $0.tokens.contains(where: { $0.boardPosition == move.toPosition }) })?
                .color {
                showCaptureFlash = capturedColor
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showCaptureFlash = nil
            }
        }

        if move.moveType == .finish {
            audioService.play(.tokenFinish)
            hapticService.trigger(.tokenFinish)
        }

        // Broadcast move
        networkService?.broadcastMove(move, gameID: gameState.gameID)
        GameStateManager.shared.currentGameState = gameState

        // Check win condition
        if let winner = GameRules.checkWinner(state: gameState) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.handleWin(winner: winner)
            }
            return
        }

        // After animation, decide next phase
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.animatingTokenID = nil
            self?.resolvePostMove(dice: dice, causedCapture: causedCapture)
        }
    }

    // MARK: - Post-Move Logic

    private func resolvePostMove(dice: DiceResult, causedCapture: Bool) {
        if gameState.remainingMoves.isEmpty {
            let bonusTurn = GameRules.currentPlayerGetsAnotherTurn(dice: dice, capturedThisTurn: causedCapture)
            if bonusTurn {
                gameState.phase = .rolling
                showToast(dice.isDouble ? "Doubles! Roll again" : "Capture bonus! Roll again")
                if gameState.currentPlayer.isAI { rollDice() }
            } else {
                advanceTurn()
            }
        } else {
            // Still have moves remaining
            gameState.phase = .moving
            legalMoves = GameRules.legalMoves(
                for: gameState.currentPlayer,
                dice: dice,
                allPlayers: gameState.players
            )
            if legalMoves.isEmpty { advanceTurn() }
            if gameState.currentPlayer.isAI { executeAITurn() }
        }
    }

    // MARK: - Turn Management

    private func advanceTurn() {
        GameRules.advanceTurn(state: &gameState)
        legalMoves = []
        selectedTokenIndex = nil
        isMyTurn = isCurrentPlayerLocalUser()
        resetTurnTimer()
        startTurnTimerIfNeeded()
        GameStateManager.shared.currentGameState = gameState

        if gameState.currentPlayer.isAI {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.rollDice()
            }
        }
    }

    // MARK: - AI

    private func executeAITurn() {
        guard let dice = gameState.currentDice else { return }
        AITurnOrchestrator.shared.executeTurn(
            player: gameState.currentPlayer,
            dice: dice,
            state: gameState
        ) { [weak self] move in
            guard let self, let move else {
                self?.advanceTurn()
                return
            }
            self.executeMove(move)
        }
    }

    // MARK: - Win Handling

    private func handleWin(winner: Player) {
        self.winner = winner
        gameState.phase = .finished
        audioService.play(.victory)
        hapticService.trigger(.victory)
        showWinScreen = true

        // Update user stats
        let isLocalUser = !winner.isAI && winner.id == AuthService.shared.currentUserID
        UserStatsService.shared.recordGameResult(
            won: isLocalUser,
            mode: gameState.mode,
            turnsElapsed: gameState.turnNumber,
            captures: gameState.captureHistory.filter { $0.capturingPlayerColor == winner.color }.count
        )

        networkService?.broadcastGameEnd(winnerID: winner.id, gameID: gameState.gameID)
        analyticsService.track(event: "game_finished", properties: [
            "winner_id": winner.id,
            "turn_count": gameState.turnNumber,
            "mode": gameState.mode.rawValue
        ])

        GameStateManager.shared.clearSavedState()
    }

    // MARK: - Turn Timer

    private func startTurnTimerIfNeeded() {
        guard gameState.mode == .onlineMultiplayer || gameState.mode == .privateRoom else { return }
        turnTimeRemaining = FeatureFlags.shared.turnTimerSeconds

        turnTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.turnTimeRemaining -= 1
                if self.turnTimeRemaining <= 0 {
                    self.turnTimer?.cancel()
                    if self.isMyTurn { self.forceSkipTurn() }
                }
            }
    }

    private func resetTurnTimer() {
        turnTimer?.cancel()
        turnTimeRemaining = FeatureFlags.shared.turnTimerSeconds
    }

    private func forceSkipTurn() {
        showToast("Time's up! Turn skipped.")
        advanceTurn()
    }

    // MARK: - Network Subscription

    private func subscribeToNetwork() {
        networkCancellable = networkService?.remoteStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] remoteState in
                self?.gameState = remoteState
                self?.isMyTurn = self?.isCurrentPlayerLocalUser() ?? false
                self?.legalMoves = []
            }
    }

    // MARK: - Helpers

    private func isCurrentPlayerLocalUser() -> Bool {
        guard gameState.mode == .onlineMultiplayer || gameState.mode == .privateRoom else {
            return true // Local modes — always your turn
        }
        return gameState.currentPlayer.id == AuthService.shared.currentUserID
    }

    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.toastMessage = nil
        }
    }

    // MARK: - Chat

    func sendChatMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard FeatureFlags.shared.isChatEnabled else { return }
        let currentUserID = AuthService.shared.currentUserID ?? ""
        let msg = ChatMessage(
            playerID: currentUserID,
            playerName: gameState.currentPlayer.displayName,
            playerColor: gameState.currentPlayer.color,
            content: text
        )
        gameState.chatMessages.append(msg)
        networkService?.broadcastChat(msg, gameID: gameState.gameID)
    }
}
