// UserProfile.swift
// User account model with XP, leveling, stats, and social features

import Foundation

// MARK: - User Profile

struct UserProfile: Codable, Identifiable {
    let id: String                    // Firebase UID
    var displayName: String
    var email: String
    var avatarURL: String?
    var selectedAvatarID: String
    var selectedThemeID: String
    var coins: Int
    var gems: Int
    var xp: Int
    var level: Int
    var isPremium: Bool
    var premiumExpiresAt: Date?
    var stats: GameStats
    var friendIDs: [String]
    var blockedIDs: [String]
    var unlockedAvatarIDs: [String]
    var unlockedThemeIDs: [String]
    var fcmToken: String?
    var lastSeenAt: Date
    var createdAt: Date
    var consecutiveLoginDays: Int
    var lastLoginDate: Date?
    var isBanned: Bool
    var banReason: String?

    init(id: String, displayName: String, email: String) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.avatarURL = nil
        self.selectedAvatarID = "default"
        self.selectedThemeID = "classic"
        self.coins = 500           // Starting coins
        self.gems = 0
        self.xp = 0
        self.level = 1
        self.isPremium = false
        self.premiumExpiresAt = nil
        self.stats = GameStats()
        self.friendIDs = []
        self.blockedIDs = []
        self.unlockedAvatarIDs = ["default"]
        self.unlockedThemeIDs = ["classic"]
        self.fcmToken = nil
        self.lastSeenAt = Date()
        self.createdAt = Date()
        self.consecutiveLoginDays = 1
        self.lastLoginDate = Date()
        self.isBanned = false
        self.banReason = nil
    }
}

// MARK: - Game Stats

struct GameStats: Codable {
    var totalGames: Int
    var wins: Int
    var losses: Int
    var draws: Int
    var currentStreak: Int
    var bestStreak: Int
    var totalTokensCaptured: Int
    var totalTokensLost: Int
    var totalDiceRolls: Int
    var doublesRolled: Int
    var averageTurnsPerGame: Double
    var fastestWinTurns: Int?

    init() {
        totalGames = 0
        wins = 0
        losses = 0
        draws = 0
        currentStreak = 0
        bestStreak = 0
        totalTokensCaptured = 0
        totalTokensLost = 0
        totalDiceRolls = 0
        doublesRolled = 0
        averageTurnsPerGame = 0.0
        fastestWinTurns = nil
    }

    var winRate: Double {
        guard totalGames > 0 else { return 0 }
        return Double(wins) / Double(totalGames)
    }
}

// MARK: - XP System

struct XPSystem {
    /// XP required to reach each level (level 1 = 0 XP)
    static func xpRequired(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        // Exponential growth: each level requires ~20% more XP than the last
        return Int(Double(level - 1) * 100.0 * pow(1.2, Double(level - 2)))
    }

    static func level(forXP xp: Int) -> Int {
        var level = 1
        while xpRequired(forLevel: level + 1) <= xp {
            level += 1
            if level >= 100 { break } // Cap at level 100
        }
        return level
    }

    static func xpForWin(mode: GameMode, playerCount: Int, turnsElapsed: Int) -> Int {
        var base = 200
        switch mode {
        case .onlineMultiplayer, .privateRoom: base = 350
        case .vsAI: base = 150
        case .localPassAndPlay: base = 100
        }
        let speedBonus = max(0, 50 - turnsElapsed)
        let competitionBonus = playerCount * 25
        return base + speedBonus + competitionBonus
    }

    static func xpForLoss() -> Int { 30 }
    static func xpForCapture() -> Int { 15 }
}

// MARK: - Avatar

struct AvatarDefinition: Identifiable, Codable {
    let id: String
    let name: String
    let imageName: String          // Asset catalog name
    let coinPrice: Int
    let gemPrice: Int
    let isPremiumOnly: Bool
    let isDefault: Bool

    static let all: [AvatarDefinition] = [
        AvatarDefinition(id: "default",  name: "Wanderer",     imageName: "avatar_wanderer",   coinPrice: 0,    gemPrice: 0,  isPremiumOnly: false, isDefault: true),
        AvatarDefinition(id: "knight",   name: "Knight",       imageName: "avatar_knight",     coinPrice: 500,  gemPrice: 0,  isPremiumOnly: false, isDefault: false),
        AvatarDefinition(id: "wizard",   name: "Wizard",       imageName: "avatar_wizard",     coinPrice: 800,  gemPrice: 0,  isPremiumOnly: false, isDefault: false),
        AvatarDefinition(id: "dragon",   name: "Dragon",       imageName: "avatar_dragon",     coinPrice: 1500, gemPrice: 0,  isPremiumOnly: false, isDefault: false),
        AvatarDefinition(id: "phoenix",  name: "Phoenix",      imageName: "avatar_phoenix",    coinPrice: 0,    gemPrice: 50, isPremiumOnly: false, isDefault: false),
        AvatarDefinition(id: "celestial",name: "Celestial",    imageName: "avatar_celestial",  coinPrice: 0,    gemPrice: 0,  isPremiumOnly: true,  isDefault: false),
    ]
}

// MARK: - Theme / Skin

struct BoardTheme: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let coinPrice: Int
    let gemPrice: Int
    let isPremiumOnly: Bool
    let previewImageName: String

    static let all: [BoardTheme] = [
        BoardTheme(id: "classic",   name: "Classic",    description: "The timeless original look",       coinPrice: 0,    gemPrice: 0,  isPremiumOnly: false, previewImageName: "theme_classic"),
        BoardTheme(id: "midnight",  name: "Midnight",   description: "Dark and mysterious night theme",  coinPrice: 1000, gemPrice: 0,  isPremiumOnly: false, previewImageName: "theme_midnight"),
        BoardTheme(id: "jungle",    name: "Jungle",     description: "Vibrant tropical green theme",     coinPrice: 1200, gemPrice: 0,  isPremiumOnly: false, previewImageName: "theme_jungle"),
        BoardTheme(id: "ocean",     name: "Ocean",      description: "Cool ocean blues and teals",       coinPrice: 1200, gemPrice: 0,  isPremiumOnly: false, previewImageName: "theme_ocean"),
        BoardTheme(id: "neon",      name: "Neon",       description: "Glowing cyberpunk neon colors",    coinPrice: 0,    gemPrice: 80, isPremiumOnly: false, previewImageName: "theme_neon"),
        BoardTheme(id: "golden",    name: "Golden",     description: "Premium golden luxury theme",      coinPrice: 0,    gemPrice: 0,  isPremiumOnly: true,  previewImageName: "theme_golden"),
    ]
}

// MARK: - Friend Request

struct FriendRequest: Identifiable, Codable {
    let id: String
    let senderID: String
    let senderName: String
    let senderAvatarURL: String?
    let receiverID: String
    var status: FriendRequestStatus
    let sentAt: Date

    enum FriendRequestStatus: String, Codable {
        case pending, accepted, declined
    }
}

// MARK: - Report

struct UserReport: Codable {
    let id: String
    let reporterID: String
    let reportedID: String
    let gameID: String?
    let reason: ReportReason
    let description: String
    let createdAt: Date

    enum ReportReason: String, Codable, CaseIterable {
        case cheating = "Cheating"
        case harassment = "Harassment"
        case inappropriateName = "Inappropriate Name"
        case spam = "Spam"
        case other = "Other"
    }
}
