// GameRulesTests.swift
// Unit tests for core game rules engine

import XCTest
@testable import ParcheesiGame

final class GameRulesTests: XCTestCase {

    // MARK: - Test Players

    private func makePlayers() -> [Player] {
        [
            Player(id: "p1", displayName: "Red",    color: .red),
            Player(id: "p2", displayName: "Blue",   color: .blue),
            Player(id: "p3", displayName: "Green",  color: .green),
            Player(id: "p4", displayName: "Yellow", color: .yellow),
        ]
    }

    // MARK: - Entry Tests

    func testCanEnterBoardWithFiveOnFirstDie() {
        let dice = DiceResult(die1: 5, die2: 3)
        XCTAssertTrue(GameRules.canEnterBoard(withDice: dice))
    }

    func testCanEnterBoardWithFiveOnSecondDie() {
        let dice = DiceResult(die1: 2, die2: 5)
        XCTAssertTrue(GameRules.canEnterBoard(withDice: dice))
    }

    func testCanEnterBoardWithSumFive() {
        let dice = DiceResult(die1: 2, die2: 3)
        XCTAssertTrue(GameRules.canEnterBoard(withDice: dice))
    }

    func testCannotEnterBoardWithoutFive() {
        let dice = DiceResult(die1: 1, die2: 2)
        XCTAssertFalse(GameRules.canEnterBoard(withDice: dice))
    }

    func testCannotEnterBoardWithFourAndTwo() {
        let dice = DiceResult(die1: 4, die2: 2)
        XCTAssertFalse(GameRules.canEnterBoard(withDice: dice))
    }

    // MARK: - Legal Moves

    func testYardTokenHasNoMovesWithoutFive() {
        var players = makePlayers()
        let dice = DiceResult(die1: 3, die2: 4)
        let moves = GameRules.legalMoves(for: players[0], dice: dice, allPlayers: players)
        // All tokens in yard, no 5 rolled → no moves
        XCTAssertTrue(moves.isEmpty)
    }

    func testYardTokenCanEnterWithFive() {
        var players = makePlayers()
        let dice = DiceResult(die1: 5, die2: 2)
        let moves = GameRules.legalMoves(for: players[0], dice: dice, allPlayers: players)
        // Should have 4 enter moves (one per token in yard)
        XCTAssertFalse(moves.isEmpty)
        XCTAssertTrue(moves.allSatisfy { $0.moveType == .enter || $0.moveType == .captureEnter })
    }

    func testOnBoardTokenCanMove() {
        var players = makePlayers()
        // Move player 0's first token onto the board
        players[0].tokens[0].state = .onBoard
        players[0].tokens[0].boardPosition = 10

        let dice = DiceResult(die1: 3, die2: 2)
        let moves = GameRules.legalMoves(for: players[0], dice: dice, allPlayers: players)
        XCTAssertFalse(moves.isEmpty)
        // Should advance to 13 (10+3) and 12 (10+2)
        let destinations = Set(moves.map { $0.toPosition })
        XCTAssertTrue(destinations.contains(13) || destinations.contains(12))
    }

    // MARK: - Capture

    func testCaptureIsDetected() {
        var players = makePlayers()
        // Red token at position 13 (blue's entry — also a non-global-safe square for red)
        players[0].tokens[0].state = .onBoard
        players[0].tokens[0].boardPosition = 10

        // Blue token at 12
        players[1].tokens[0].state = .onBoard
        players[1].tokens[0].boardPosition = 12

        let dice = DiceResult(die1: 2, die2: 4)
        let moves = GameRules.legalMoves(for: players[0], dice: dice, allPlayers: players)
        let captureMove = moves.first { $0.moveType == .capture }
        // If 10+2=12 and blue is there, should be a capture
        // (unless 12 is a safe square — it is not a global safe square)
        XCTAssertNotNil(captureMove)
    }

    // MARK: - Win Condition

    func testWinConditionAllTokensFinished() {
        var players = makePlayers()
        for i in players[0].tokens.indices {
            players[0].tokens[i].isFinished = true
            players[0].tokens[i].state = .finished
        }
        var state = GameState(mode: .localPassAndPlay, players: players)
        let winner = GameRules.checkWinner(state: state)
        XCTAssertNotNil(winner)
        XCTAssertEqual(winner?.color, .red)
    }

    func testNoWinnerWhenTokensRemain() {
        var players = makePlayers()
        // Finish only 3 of 4 tokens
        for i in 0..<3 {
            players[0].tokens[i].isFinished = true
        }
        var state = GameState(mode: .localPassAndPlay, players: players)
        let winner = GameRules.checkWinner(state: state)
        XCTAssertNil(winner)
    }

    // MARK: - Safe Squares

    func testGlobalSafeSquaresAreCorrect() {
        XCTAssertTrue(GameRules.isGlobalSafe(0))
        XCTAssertTrue(GameRules.isGlobalSafe(8))
        XCTAssertTrue(GameRules.isGlobalSafe(13))
        XCTAssertFalse(GameRules.isGlobalSafe(1))
        XCTAssertFalse(GameRules.isGlobalSafe(7))
    }

    // MARK: - Dice

    func testDiceRollIsInRange() {
        for _ in 0..<100 {
            let result = DiceResult.roll()
            XCTAssertGreaterThanOrEqual(result.die1, 1)
            XCTAssertLessThanOrEqual(result.die1, 6)
            XCTAssertGreaterThanOrEqual(result.die2, 1)
            XCTAssertLessThanOrEqual(result.die2, 6)
        }
    }

    func testDoubleDetection() {
        let double = DiceResult(die1: 3, die2: 3)
        XCTAssertTrue(double.isDouble)
        let notDouble = DiceResult(die1: 3, die2: 4)
        XCTAssertFalse(notDouble.isDouble)
    }

    // MARK: - XP System

    func testLevelCalculation() {
        XCTAssertEqual(XPSystem.level(forXP: 0), 1)
        XCTAssertEqual(XPSystem.level(forXP: 99), 1)
        XCTAssertGreaterThan(XPSystem.level(forXP: 10000), 5)
    }

    func testXPForWinIsPositive() {
        let xp = XPSystem.xpForWin(mode: .onlineMultiplayer, playerCount: 4, turnsElapsed: 20)
        XCTAssertGreaterThan(xp, 0)
    }
}
