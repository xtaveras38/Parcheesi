// UserStatsService.swift
// Updates player stats and XP after each game

import Foundation

final class UserStatsService {

    static let shared = UserStatsService()
    private init() {}

    func recordGameResult(won: Bool, mode: GameMode, turnsElapsed: Int, captures: Int) {
        guard let uid = AuthService.shared.currentUserID else { return }

        Task {
            let xpGained: Int
            if won {
                xpGained = XPSystem.xpForWin(mode: mode, playerCount: 4, turnsElapsed: turnsElapsed)
                    + captures * XPSystem.xpForCapture()
            } else {
                xpGained = XPSystem.xpForLoss() + captures * XPSystem.xpForCapture()
            }

            do {
                // Increment XP
                try await UserProfileService.shared.addXP(uid: uid, amount: xpGained)

                // Update stats via server-side logic (Firebase Cloud Function handles atomicity)
                // Direct update shown here for local play:
                if let profile = UserProfileService.shared.cachedProfile {
                    var stats = profile.stats
                    stats.totalGames += 1
                    if won {
                        stats.wins += 1
                        stats.currentStreak += 1
                        stats.bestStreak = max(stats.bestStreak, stats.currentStreak)
                    } else {
                        stats.losses += 1
                        stats.currentStreak = 0
                    }
                    stats.totalTokensCaptured += captures
                    let prevAvg = stats.averageTurnsPerGame
                    stats.averageTurnsPerGame = prevAvg + (Double(turnsElapsed) - prevAvg) / Double(stats.totalGames)
                    if won {
                        if let fastest = stats.fastestWinTurns {
                            stats.fastestWinTurns = min(fastest, turnsElapsed)
                        } else {
                            stats.fastestWinTurns = turnsElapsed
                        }
                    }
                    try await UserProfileService.shared.updateStats(uid: uid, stats: stats)
                }
            } catch {
                print("[UserStatsService] Stats update error: \(error)")
            }
        }
    }
}
