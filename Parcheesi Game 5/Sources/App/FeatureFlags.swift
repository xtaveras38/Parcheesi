// FeatureFlags.swift
// Remote-controlled feature toggles via Firebase Remote Config

import Foundation
import FirebaseRemoteConfig

/// Centralized feature flag system. All flags can be overridden remotely
/// without requiring an App Store update.
final class FeatureFlags: ObservableObject {

    static let shared = FeatureFlags()

    // MARK: - Published Flags

    @Published var isOnlineMultiplayerEnabled: Bool = true
    @Published var isAIEnabled: Bool = true
    @Published var isChatEnabled: Bool = true
    @Published var isIAPEnabled: Bool = true
    @Published var isRewardedAdsEnabled: Bool = true
    @Published var isDailyRewardEnabled: Bool = true
    @Published var isLeaderboardEnabled: Bool = true
    @Published var isFriendSystemEnabled: Bool = true
    @Published var isSpectatorModeEnabled: Bool = false
    @Published var isTournamentModeEnabled: Bool = false
    @Published var maxPlayersPerRoom: Int = 4
    @Published var turnTimerSeconds: Int = 60
    @Published var aiThinkingDelayMs: Int = 800

    // MARK: - Remote Config

    private let remoteConfig = RemoteConfig.remoteConfig()

    private init() {
        setDefaults()
    }

    func loadRemoteConfig() {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 3600 // 1 hour in production
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults(fromPlist: "RemoteConfigDefaults")

        remoteConfig.fetchAndActivate { [weak self] status, error in
            if let error = error {
                print("[FeatureFlags] Fetch error: \(error.localizedDescription)")
                return
            }
            DispatchQueue.main.async {
                self?.applyRemoteValues()
            }
        }
    }

    // MARK: - Private Helpers

    private func setDefaults() {
        // Defaults are defined above; remote config overrides on fetch
    }

    private func applyRemoteValues() {
        isOnlineMultiplayerEnabled = remoteConfig["online_multiplayer_enabled"].boolValue
        isAIEnabled = remoteConfig["ai_enabled"].boolValue
        isChatEnabled = remoteConfig["chat_enabled"].boolValue
        isIAPEnabled = remoteConfig["iap_enabled"].boolValue
        isRewardedAdsEnabled = remoteConfig["rewarded_ads_enabled"].boolValue
        isDailyRewardEnabled = remoteConfig["daily_reward_enabled"].boolValue
        isLeaderboardEnabled = remoteConfig["leaderboard_enabled"].boolValue
        isFriendSystemEnabled = remoteConfig["friend_system_enabled"].boolValue
        isSpectatorModeEnabled = remoteConfig["spectator_mode_enabled"].boolValue
        isTournamentModeEnabled = remoteConfig["tournament_mode_enabled"].boolValue
        maxPlayersPerRoom = remoteConfig["max_players_per_room"].numberValue.intValue
        turnTimerSeconds = remoteConfig["turn_timer_seconds"].numberValue.intValue
        aiThinkingDelayMs = remoteConfig["ai_thinking_delay_ms"].numberValue.intValue
    }
}
