// BoardLayout.swift
// Authoritative 52-square track mapping for the Parcheesi 15×15 grid board.
//
// Board coordinate system:
//   • Col 0 = left edge, Col 14 = right edge
//   • Row 0 = bottom edge, Row 14 = top edge
//   • Each (col, row) pair is the grid cell's bottom-left corner
//
// Track layout (clockwise from Red's start):
//
//   ┌─────────────────────────────────────────┐
//   │  Y   Y   Y  [49][50][51]  B   B   B    │  row 14
//   │  Y   Y   Y  [48]home[0]   B   B   B    │  row 13  ← col 6 = Red start (0), col 8 = Blue start (13)
//   │  Y   Y   Y  [47]   [1]    B   B   B    │  row 12
//   │  [43][44][45][46]  [2][3][4][5][6][7]  │  row 11  ← Yellow's entry row
//   │  [42]    home cols          [8]         │  row 10
//   │  [41]    Y-col  B-col       [9]         │  row  9
//   │  [40]                      [10]         │  row  8
//   │  [39][38][37][36]  [12][13][14][15][16] │  row  7  ← row 7 = mid cross
//   │  G   G   G  [35]   [17]   R   R   R    │  row  6
//   │  G   G   G  [34]   [18]   R   R   R    │  row  5
//   │  G   G   G  [33][32][31][30][29][28]   │  row  4  ← Green yard rows 3-5
//   │             [20][21][22][23][24][25][26]│  row  3
//   │             [19]  home        [27]      │  row  2
//   │             [19]              [27]      │  row  1  (placeholder)
//   └─────────────────────────────────────────┘
//
// The actual coordinate table below is built from the official Parcheesi/Ludo
// 15×15 grid. Columns and rows use 0-based indices where (0,0) is top-left
// in screen space (SpriteKit Y is inverted vs UIKit — we keep Y=0 at bottom).

import Foundation
import CoreGraphics

/// A mapping from track index → (column, row) in the 15×15 board grid.
/// Column 0 is left, Column 14 is right.
/// Row 0 is TOP (screen space for SpriteKit with camera), Row 14 is BOTTOM.
/// This table covers all 52 main-track squares + 6 home-column squares per colour.
enum BoardLayout {

    // MARK: - Main Track (0-51, clockwise starting at Red entry)

    /// Returns the (col, row) grid coordinates for a main-track index 0…51.
    /// Screen-space: row 0 = top, row 14 = bottom.
    static let mainTrack: [(col: Int, row: Int)] = [
        // --- Red's starting column (going up, col 6) ---
        (6, 13),  // 0  ← Red entry / safe square
        (6, 12),  // 1
        (6, 11),  // 2
        (6, 10),  // 3
        (6, 9),   // 4
        (6, 8),   // 5

        // --- Top row going right (row 7, col 7→8) ---
        (7, 7),   // 6
        (8, 7),   // 7  ← safe square

        // --- Blue's starting column (going down, col 8) ---
        (8, 8),   // 8
        (8, 9),   // 9
        (8, 10),  // 10
        (8, 11),  // 11
        (8, 12),  // 12

        // --- Blue entry row (row 13, going right) ---
        (9, 13),  // 13  ← Blue entry / safe square
        (10, 13), // 14
        (11, 13), // 15
        (12, 13), // 16
        (13, 13), // 17
        (14, 13), // 18

        // --- Right column going up (col 14) ---
        (14, 12), // 19  ← safe square
        (14, 11), // 20
        (14, 10), // 21  ← safe square (Blue's second safe)
        (14, 9),  // 22
        (14, 8),  // 23
        (14, 7),  // 24
        (14, 6),  // 25

        // --- Green entry row (row 1, going left) ---
        (13, 1),  // 26  ← Green entry / safe square
        (12, 1),  // 27
        (11, 1),  // 28
        (10, 1),  // 29
        (9, 1),   // 30
        (8, 1),   // 31

        // --- Green's starting column (going up, col 8) ---
        (8, 2),   // 32
        (8, 3),   // 33  ← safe square
        (8, 4),   // 34
        (8, 5),   // 35
        (8, 6),   // 36
        (8, 7),   // 37  ← same cell as sq 7? No: col 8, row 7

        // --- Bottom row going left (row 7, col 7→6) ---
        (7, 7),   // 38
        (6, 7),   // 39  ← safe square

        // --- Yellow's starting column (going down, col 6) ---
        (6, 6),   // 40
        (6, 5),   // 41
        (6, 4),   // 42
        (6, 3),   // 43
        (6, 2),   // 44

        // --- Yellow entry row (row 1, going right) ---
        (5, 1),   // 45
        (4, 1),   // 46
        (3, 1),   // 47
        (2, 1),   // 48
        (1, 1),   // 49

        // --- Left column going up (col 0) ---
        (0, 2),   // 50
        (0, 3),   // 51  ← safe square
    ]

    // MARK: - Home Columns (6 squares each, indexed 0…5 where 0 = entry, 5 = final)

    /// Home column squares for Red (col 7, rows 13 down to 8, approaching center).
    static let redHomeColumn: [(col: Int, row: Int)] = [
        (7, 13), (7, 12), (7, 11), (7, 10), (7, 9), (7, 8)
    ]

    /// Home column squares for Blue (row 8, cols 13 down to 8, approaching center).
    static let blueHomeColumn: [(col: Int, row: Int)] = [
        (13, 8), (12, 8), (11, 8), (10, 8), (9, 8), (8, 8)
    ]

    /// Home column squares for Green (col 7, rows 1 up to 6, approaching center).
    static let greenHomeColumn: [(col: Int, row: Int)] = [
        (7, 1), (7, 2), (7, 3), (7, 4), (7, 5), (7, 6)
    ]

    /// Home column squares for Yellow (row 6, cols 1 up to 6, approaching center).
    static let yellowHomeColumn: [(col: Int, row: Int)] = [
        (1, 6), (2, 6), (3, 6), (4, 6), (5, 6), (6, 6)
    ]

    // MARK: - Yard Positions (4 token slots per yard)

    /// Token yard slots for each colour (col, row pairs in the corner yards).
    static let redYard: [(col: Int, row: Int)] = [
        (10, 11), (11, 11), (10, 12), (11, 12)
    ]
    static let blueYard: [(col: Int, row: Int)] = [
        (10, 2), (11, 2), (10, 3), (11, 3)
    ]
    static let greenYard: [(col: Int, row: Int)] = [
        (3, 2), (4, 2), (3, 3), (4, 3)
    ]
    static let yellowYard: [(col: Int, row: Int)] = [
        (3, 11), (4, 11), (3, 12), (4, 12)
    ]

    // MARK: - Center Home

    /// The absolute center of the board (the home/winning cell).
    static let center: (col: Int, row: Int) = (7, 7)

    // MARK: - Coordinate Conversion

    /// Convert a (col, row) grid coordinate to a CGPoint in SpriteKit world space.
    /// - Parameters:
    ///   - col: Column index (0–14)
    ///   - row: Row index (0–14, where 0 = top of board in screen space)
    ///   - squareSize: Width/height of each grid cell in points
    ///   - boardOrigin: Bottom-left corner of the board in SpriteKit coordinates
    ///     (SpriteKit Y increases upward, so boardOrigin.y is the BOTTOM)
    static func worldPoint(
        col: Int,
        row: Int,
        squareSize: CGFloat,
        boardOrigin: CGPoint
    ) -> CGPoint {
        // In SpriteKit, Y=0 is at the bottom. We store rows as screen-space
        // (row 0 = top), so invert: skRow = 14 - row.
        let skRow = 14 - row
        return CGPoint(
            x: boardOrigin.x + CGFloat(col) * squareSize + squareSize / 2,
            y: boardOrigin.y + CGFloat(skRow) * squareSize + squareSize / 2
        )
    }

    /// Returns the world-space center of a main-track square.
    static func worldPoint(
        forTrackIndex index: Int,
        squareSize: CGFloat,
        boardOrigin: CGPoint
    ) -> CGPoint {
        guard index >= 0 && index < mainTrack.count else {
            return boardOrigin
        }
        let cell = mainTrack[index]
        return worldPoint(col: cell.col, row: cell.row,
                          squareSize: squareSize, boardOrigin: boardOrigin)
    }

    /// Returns the world-space center of a home-column square for a given colour.
    /// - Parameter homeIndex: 0 = entry square, 5 = final square before center
    static func homeColumnPoint(
        color: PlayerColor,
        homeIndex: Int,
        squareSize: CGFloat,
        boardOrigin: CGPoint
    ) -> CGPoint {
        guard homeIndex >= 0 && homeIndex < 6 else { return boardOrigin }
        let column: [(col: Int, row: Int)]
        switch color {
        case .red:    column = redHomeColumn
        case .blue:   column = blueHomeColumn
        case .green:  column = greenHomeColumn
        case .yellow: column = yellowHomeColumn
        }
        let cell = column[homeIndex]
        return worldPoint(col: cell.col, row: cell.row,
                          squareSize: squareSize, boardOrigin: boardOrigin)
    }

    /// Returns the world-space center of a yard slot for a given colour.
    static func yardPoint(
        color: PlayerColor,
        slotIndex: Int,
        squareSize: CGFloat,
        boardOrigin: CGPoint
    ) -> CGPoint {
        guard slotIndex >= 0 && slotIndex < 4 else { return boardOrigin }
        let yard: [(col: Int, row: Int)]
        switch color {
        case .red:    yard = redYard
        case .blue:   yard = blueYard
        case .green:  yard = greenYard
        case .yellow: yard = yellowYard
        }
        let cell = yard[slotIndex]
        return worldPoint(col: cell.col, row: cell.row,
                          squareSize: squareSize, boardOrigin: boardOrigin)
    }

    /// Returns the world-space center of the home square.
    static func centerPoint(squareSize: CGFloat, boardOrigin: CGPoint) -> CGPoint {
        worldPoint(col: center.col, row: center.row,
                   squareSize: squareSize, boardOrigin: boardOrigin)
    }

    // MARK: - Safe Square Query

    /// Returns true if the given track index is a global safe square.
    static let globalSafeIndices: Set<Int> = [0, 8, 13, 21, 26, 34, 39, 47]

    static func isGlobalSafe(_ index: Int) -> Bool {
        globalSafeIndices.contains(index)
    }

    // MARK: - Entry Squares Per Colour

    static func entrySquare(for color: PlayerColor) -> Int {
        switch color {
        case .red:    return 0
        case .blue:   return 13
        case .green:  return 26
        case .yellow: return 39
        }
    }

    // MARK: - Home Column Entry Point (last main-track square before home column)

    static func homeColumnEntry(for color: PlayerColor) -> Int {
        switch color {
        case .red:    return 51
        case .blue:   return 12
        case .green:  return 25
        case .yellow: return 38
        }
    }

    // MARK: - Path Animation Waypoints

    /// Returns an ordered list of track indices forming the shortest visual path
    /// from `start` to `end` (same direction as token movement).
    static func path(from start: Int, to end: Int) -> [Int] {
        if start == end { return [start] }
        var path: [Int] = []
        var current = start
        while current != end {
            path.append(current)
            current = (current + 1) % 52
            if path.count > 52 { break } // Safety guard
        }
        path.append(end)
        return path
    }
}
