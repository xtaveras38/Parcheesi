// DailyRewardManager.swift
// Daily login reward system with streak tracking

import Foundation

struct DailyReward {
    let coins: Int
    let gems: Int
    let day: Int
}

final class DailyRewardManager {

    static let shared = DailyRewardManager()
    private init() {}

    private let lastClaimKey = "last_daily_reward_claim"
    private let streakKey = "daily_reward_streak"

    // MARK: - State

    var hasUnclaimedReward: Bool {
        guard FeatureFlags.shared.isDailyRewardEnabled else { return false }
        guard let last = lastClaimDate else { return true }
        return !Calendar.current.isDateInToday(last)
    }

    var consecutiveDays: Int {
        UserDefaults.standard.integer(forKey: streakKey)
    }

    var lastClaimDate: Date? {
        UserDefaults.standard.object(forKey: lastClaimKey) as? Date
    }

    var currentReward: DailyReward {
        rewardForDay(consecutiveDays)
    }

    // MARK: - Claim

    func checkDailyReward() {
        guard hasUnclaimedReward else { return }
        // Streak validation
        if let last = lastClaimDate {
            let daysSinceLast = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
            if daysSinceLast > 1 {
                // Streak broken
                UserDefaults.standard.set(1, forKey: streakKey)
            }
        }
    }

    func claimReward() {
        guard hasUnclaimedReward else { return }
        let reward = currentReward

        // Update streak
        let newStreak = consecutiveDays + 1
        UserDefaults.standard.set(newStreak, forKey: streakKey)
        UserDefaults.standard.set(Date(), forKey: lastClaimKey)

        // Grant reward
        guard let uid = AuthService.shared.currentUserID else { return }
        Task {
            if reward.coins > 0 {
                try? await UserProfileService.shared.addCoins(uid: uid, amount: reward.coins)
            }
            if reward.gems > 0 {
                try? await UserProfileService.shared.addGems(uid: uid, amount: reward.gems)
            }
        }

        AnalyticsService.shared.track(event: "daily_reward_claimed", properties: [
            "day": newStreak,
            "coins": reward.coins,
            "gems": reward.gems
        ])
    }

    // MARK: - Reward Schedule

    private func rewardForDay(_ day: Int) -> DailyReward {
        // Progressive rewards; every 7 days is a "mega" reward
        switch day % 7 {
        case 0: return DailyReward(coins: 0, gems: 5, day: day)    // Day 7 / 14 / 21 — gem reward
        case 1: return DailyReward(coins: 100, gems: 0, day: day)
        case 2: return DailyReward(coins: 150, gems: 0, day: day)
        case 3: return DailyReward(coins: 200, gems: 0, day: day)
        case 4: return DailyReward(coins: 250, gems: 1, day: day)
        case 5: return DailyReward(coins: 300, gems: 1, day: day)
        case 6: return DailyReward(coins: 350, gems: 2, day: day)
        default: return DailyReward(coins: 100, gems: 0, day: day)
        }
    }
}
