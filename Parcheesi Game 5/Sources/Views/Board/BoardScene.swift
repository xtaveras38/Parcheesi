// BoardScene.swift
// SpriteKit scene that renders the Parcheesi board and animates tokens

import SpriteKit
import SwiftUI

final class BoardScene: SKScene {

    // MARK: - Configuration

    weak var gameViewModel: GameViewModel?
    var theme: BoardThemeConfig = .classic

    // MARK: - Nodes

    private var boardNode: SKShapeNode!
    private var tokenNodes: [UUID: SKShapeNode] = [:]
    private var squareNodes: [Int: SKShapeNode] = [:]
    private var highlightNodes: [SKShapeNode] = []

    // MARK: - Layout

    private var squareSize: CGFloat { min(size.width, size.height) / 15 }
    private var boardOrigin: CGPoint {
        CGPoint(
            x: (size.width - squareSize * 15) / 2,
            y: (size.height - squareSize * 15) / 2
        )
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(theme.backgroundColor)
        setupBoard()
        if let state = gameViewModel?.gameState {
            renderTokens(state: state)
        }
        subscribeToViewModel()
    }

    // MARK: - Board Setup

    private func setupBoard() {
        drawBoardBackground()
        drawMainTrack()
        drawHomeYards()
        drawHomeColumns()
        drawCenterHome()
        drawSafeSquareMarkers()
    }

    private func drawBoardBackground() {
        let board = SKShapeNode(rect: CGRect(origin: boardOrigin,
                                             size: CGSize(width: squareSize * 15, height: squareSize * 15)),
                                cornerRadius: 8)
        board.fillColor = UIColor(theme.boardColor)
        board.strokeColor = UIColor(theme.borderColor)
        board.lineWidth = 2
        addChild(board)
        boardNode = board
    }

    private func drawMainTrack() {
        // Use BoardLayout for authoritative 52-square track positions
        for i in 0..<52 {
            let pos = BoardLayout.worldPoint(forTrackIndex: i,
                                             squareSize: squareSize,
                                             boardOrigin: boardOrigin)
            let square = makeSquare(at: pos, color: squareColor(forIndex: i))
            square.name = "square_\(i)"
            squareNodes[i] = square
            addChild(square)
        }
    }

    private func drawHomeYards() {
        // 4 corner 6x6 yards, one per player
        let corners: [(CGFloat, CGFloat, PlayerColor)] = [
            (0, 9, .red),
            (9, 9, .blue),
            (9, 0, .green),
            (0, 0, .yellow)
        ]
        for (col, row, color) in corners {
            for r in 0..<4 {
                for c in 0..<4 {
                    let x = boardOrigin.x + (col + CGFloat(c) + 1) * squareSize
                    let y = boardOrigin.y + (row + CGFloat(r) + 1) * squareSize
                    let node = makeSquare(at: CGPoint(x: x, y: y), color: UIColor(color.swiftUIColor).withAlphaComponent(0.3))
                    node.name = "yard_\(color.rawValue)_\(r)_\(c)"
                    addChild(node)
                }
            }
        }
    }

    private func drawHomeColumns() {
        let columns: [(Int, Int, Int, PlayerColor)] = [
            (6, 9, 0, 1, .red),    // red: column going up from row 6-1
            (9, 6, 1, 0, .blue),   // blue: row going left from col 9-14
            (6, 6, 0, -1, .green), // green: column going down
            (6, 6, -1, 0, .yellow) // yellow: row going right
        ].enumerated().map { i, _ in (0,0,0,.red) } // placeholder — actual layout below

        // Draw home column squares
        drawHomeColumn(color: .red,    startCol: 7, startRow: 8, dx: 0, dy: -1)
        drawHomeColumn(color: .blue,   startCol: 8, startRow: 7, dx: -1, dy: 0)
        drawHomeColumn(color: .green,  startCol: 7, startRow: 6, dx: 0,  dy: 1)
        drawHomeColumn(color: .yellow, startCol: 6, startRow: 7, dx: 1,  dy: 0)
    }

    private func drawHomeColumn(color: PlayerColor, startCol: Int, startRow: Int, dx: Int, dy: Int) {
        for i in 0..<6 {
            let col = startCol + i * dx
            let row = startRow + i * dy
            let x = boardOrigin.x + CGFloat(col) * squareSize + squareSize / 2
            let y = boardOrigin.y + CGFloat(row) * squareSize + squareSize / 2
            let node = makeSquare(at: CGPoint(x: x, y: y), color: UIColor(color.swiftUIColor).withAlphaComponent(0.5))
            node.name = "home_col_\(color.rawValue)_\(i)"
            addChild(node)
        }
    }

    private func drawCenterHome() {
        // Center triangle pattern
        let center = CGPoint(
            x: boardOrigin.x + 7.5 * squareSize,
            y: boardOrigin.y + 7.5 * squareSize
        )
        let size = squareSize * 3

        let centerNode = SKShapeNode(circleOfRadius: size / 2)
        centerNode.position = center
        centerNode.fillColor = UIColor(theme.centerColor)
        centerNode.strokeColor = UIColor(theme.borderColor)
        addChild(centerNode)

        let starLabel = SKLabelNode(text: "🏆")
        starLabel.fontSize = size * 0.5
        starLabel.verticalAlignmentMode = .center
        starLabel.position = center
        addChild(starLabel)
    }

    private func drawSafeSquareMarkers() {
        for index in BoardLayout.globalSafeIndices {
            if let node = squareNodes[index] {
                let star = SKLabelNode(text: "★")
                star.fontSize = squareSize * 0.5
                star.fontColor = UIColor(theme.safeSquareColor)
                star.verticalAlignmentMode = .center
                star.position = node.position
                addChild(star)
            }
        }
    }

    // MARK: - Token Rendering

    private func renderTokens(state: GameState) {
        // Remove existing tokens
        tokenNodes.values.forEach { $0.removeFromParent() }
        tokenNodes.removeAll()

        for player in state.players {
            for token in player.tokens {
                let node = makeTokenNode(color: player.color)
                node.name = "token_\(token.id.uuidString)"
                node.position = tokenPosition(for: token, player: player, allPlayers: state.players)
                addChild(node)
                tokenNodes[token.id] = node
            }
        }
    }

    private func makeTokenNode(color: PlayerColor) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: squareSize * 0.38)
        node.fillColor = UIColor(color.swiftUIColor)
        node.strokeColor = .white
        node.lineWidth = 2
        node.zPosition = 10
        // Shadow
        let shadow = SKShapeNode(circleOfRadius: squareSize * 0.38)
        shadow.fillColor = .black
        shadow.alpha = 0.3
        shadow.position = CGPoint(x: 1.5, y: -1.5)
        shadow.zPosition = 9
        node.addChild(shadow)
        return node
    }

    // MARK: - Animations

    func animateTokenMove(tokenID: UUID, from: CGPoint, to: CGPoint, completion: @escaping () -> Void) {
        guard let node = tokenNodes[tokenID] else {
            completion()
            return
        }
        // Bounce arc animation
        let midPoint = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2 + 30)
        let path = UIBezierPath()
        path.move(to: from)
        path.addQuadCurve(to: to, controlPoint: midPoint)

        let move = SKAction.follow(path.cgPath, asOffset: false, orientToPath: false, duration: 0.35)
        move.timingMode = .easeInEaseOut

        let scale = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.15),
            SKAction.scale(to: 1.0, duration: 0.2)
        ])

        node.run(SKAction.group([move, scale])) {
            completion()
        }
    }

    func highlightLegalMoves(_ moves: [LegalMove], state: GameState) {
        clearHighlights()

        for move in moves {
            let pos = BoardLayout.worldPoint(forTrackIndex: move.toPosition,
                                             squareSize: squareSize,
                                             boardOrigin: boardOrigin)
            let highlight = SKShapeNode(circleOfRadius: squareSize * 0.45)
            highlight.fillColor = UIColor.white.withAlphaComponent(0.35)
            highlight.strokeColor = UIColor.white
            highlight.lineWidth = 2
            highlight.position = pos
            highlight.zPosition = 8
            highlight.name = "highlight_\(move.toPosition)"

            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.15, duration: 0.5),
                SKAction.scale(to: 0.95, duration: 0.5)
            ])
            highlight.run(SKAction.repeatForever(pulse))

            addChild(highlight)
            highlightNodes.append(highlight)
        }
    }

    func clearHighlights() {
        highlightNodes.forEach { $0.removeFromParent() }
        highlightNodes.removeAll()
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let vm = gameViewModel,
              vm.gameState.phase == .moving,
              vm.isMyTurn else { return }

        let location = touch.location(in: self)
        let nodesAtPoint = nodes(at: location)

        for node in nodesAtPoint {
            if let name = node.name, name.starts(with: "token_") {
                let tokenIDStr = String(name.dropFirst(6))
                if let tokenID = UUID(uuidString: tokenIDStr) {
                    handleTokenTap(tokenID: tokenID, vm: vm)
                    return
                }
            }
        }
    }

    private func handleTokenTap(tokenID: UUID, vm: GameViewModel) {
        let state = vm.gameState
        let player = state.currentPlayer
        guard let tokenIndex = player.tokens.firstIndex(where: { $0.id == tokenID }) else { return }
        guard let dice = state.currentDice else { return }

        let matchingMoves = vm.legalMoves.filter { $0.tokenIndex == tokenIndex }
        guard let firstMove = matchingMoves.first else { return }

        vm.executeMove(firstMove)
    }

    // MARK: - Position Helpers (all delegated to BoardLayout)

    private func boardPosition(forSquare index: Int) -> CGPoint {
        BoardLayout.worldPoint(forTrackIndex: index,
                               squareSize: squareSize,
                               boardOrigin: boardOrigin)
    }

    private func tokenPosition(for token: Token, player: Player, allPlayers: [Player]) -> CGPoint {
        switch token.state {
        case .inYard:
            let slotIndex = player.tokens.firstIndex(where: { $0.id == token.id }) ?? 0
            return BoardLayout.yardPoint(color: player.color,
                                         slotIndex: slotIndex,
                                         squareSize: squareSize,
                                         boardOrigin: boardOrigin)

        case .onBoard:
            let base = boardPosition(forSquare: token.boardPosition)
            // Spread tokens that share a square into a 2×2 sub-grid
            let sharing = allPlayers.flatMap { $0.tokens }
                .filter { $0.state == .onBoard && $0.boardPosition == token.boardPosition }
            if sharing.count > 1 {
                let spread = squareSize * 0.22
                let offsets: [CGPoint] = [
                    CGPoint(x: -spread, y:  spread),
                    CGPoint(x:  spread, y:  spread),
                    CGPoint(x: -spread, y: -spread),
                    CGPoint(x:  spread, y: -spread)
                ]
                let idx = sharing.firstIndex(where: { $0.id == token.id }) ?? 0
                let off = offsets[min(idx, offsets.count - 1)]
                return CGPoint(x: base.x + off.x, y: base.y + off.y)
            }
            return base

        case .inHomeColumn:
            let homeIndex = token.boardPosition - GameRules.mainTrackLength
            return BoardLayout.homeColumnPoint(color: player.color,
                                               homeIndex: homeIndex,
                                               squareSize: squareSize,
                                               boardOrigin: boardOrigin)

        case .finished:
            return BoardLayout.centerPoint(squareSize: squareSize, boardOrigin: boardOrigin)
        }
    }

    private func squareColor(forIndex index: Int) -> UIColor {
        if BoardLayout.isGlobalSafe(index) {
            return UIColor(theme.safeSquareColor).withAlphaComponent(0.3)
        }
        for color in PlayerColor.allCases {
            if index == BoardLayout.entrySquare(for: color) {
                return UIColor(color.swiftUIColor).withAlphaComponent(0.5)
            }
        }
        return UIColor(theme.trackColor)
    }

    private func makeSquare(at position: CGPoint, color: UIColor) -> SKShapeNode {
        let node = SKShapeNode(rect: CGRect(
            x: -squareSize / 2 + 1,
            y: -squareSize / 2 + 1,
            width: squareSize - 2,
            height: squareSize - 2
        ), cornerRadius: 3)
        node.position = position
        node.fillColor = color
        node.strokeColor = UIColor(theme.borderColor).withAlphaComponent(0.4)
        node.lineWidth = 0.5
        return node
    }

    // MARK: - ViewModel Subscription

    private func subscribeToViewModel() {
        // Observe published changes from ViewModel
        // In production, use Combine publishers via a bridge object
        // For brevity, polling is shown; replace with proper observation
    }
}

// MARK: - Board Theme Config

struct BoardThemeConfig {
    let backgroundColor: Color
    let boardColor: Color
    let trackColor: Color
    let safeSquareColor: Color
    let centerColor: Color
    let borderColor: Color

    static let classic = BoardThemeConfig(
        backgroundColor: Color(red: 0.95, green: 0.93, blue: 0.88),
        boardColor: Color(red: 0.98, green: 0.96, blue: 0.92),
        trackColor: Color(red: 0.9, green: 0.87, blue: 0.82),
        safeSquareColor: Color(red: 0.4, green: 0.75, blue: 0.4),
        centerColor: Color(red: 0.95, green: 0.8, blue: 0.2),
        borderColor: Color(red: 0.5, green: 0.4, blue: 0.3)
    )

    static let midnight = BoardThemeConfig(
        backgroundColor: Color(red: 0.08, green: 0.08, blue: 0.15),
        boardColor: Color(red: 0.12, green: 0.12, blue: 0.22),
        trackColor: Color(red: 0.18, green: 0.18, blue: 0.3),
        safeSquareColor: Color(red: 0.3, green: 0.9, blue: 0.5),
        centerColor: Color(red: 0.7, green: 0.5, blue: 1.0),
        borderColor: Color(red: 0.4, green: 0.4, blue: 0.6)
    )
}
