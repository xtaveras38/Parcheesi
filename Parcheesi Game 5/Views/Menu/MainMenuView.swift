// MainMenuView.swift
// Main menu with game mode selection, daily reward, and navigation

import SwiftUI

struct MainMenuView: View {

    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var featureFlags: FeatureFlags
    @StateObject private var lobbyVM = LobbyViewModel()
    @State private var showDailyReward = false
    @State private var showProfile = false
    @State private var showStore = false
    @State private var showLeaderboard = false
    @State private var selectedMode: GameMode?
    @State private var navigateToGame: GameState?
    @State private var navigateToLobby = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated background gradient
                AnimatedBackgroundView()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top bar
                    topBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    Spacer()

                    // Game logo
                    gameLogo

                    Spacer()

                    // Mode buttons
                    modeSelectorGrid
                        .padding(.horizontal, 20)

                    Spacer()

                    // Bottom action row
                    bottomActionRow
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $navigateToGame) { state in
                GameScreenView(gameState: state)
            }
            .navigationDestination(isPresented: $navigateToLobby) {
                LobbyView(viewModel: lobbyVM)
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(isPresented: $showStore) {
                StoreView()
            }
            .sheet(isPresented: $showLeaderboard) {
                LeaderboardView()
            }
            .sheet(isPresented: $showDailyReward) {
                DailyRewardView()
            }
            .onAppear {
                if DailyRewardManager.shared.hasUnclaimedReward {
                    showDailyReward = true
                }
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            // Avatar / Profile
            Button { showProfile = true } label: {
                AvatarView(
                    avatarID: authViewModel.currentUser?.selectedAvatarID ?? "default",
                    size: 44
                )
                .overlay(
                    Circle().stroke(Color.white.opacity(0.8), lineWidth: 2)
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(authViewModel.currentUser?.displayName ?? "Guest")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                if let profile = authViewModel.currentUser {
                    XPBarView(xp: profile.xp, level: profile.level)
                        .frame(width: 100, height: 8)
                }
            }

            Spacer()

            // Coin balance
            CurrencyBadge(
                icon: "🪙",
                value: authViewModel.currentUser?.coins ?? 0
            )

            // Gems balance
            CurrencyBadge(
                icon: "💎",
                value: authViewModel.currentUser?.gems ?? 0
            )

            // Store
            Button { showStore = true } label: {
                Image(systemName: "bag.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Circle().fill(.white.opacity(0.2)))
            }
        }
    }

    // MARK: - Logo

    private var gameLogo: some View {
        VStack(spacing: 8) {
            Text("🎲")
                .font(.system(size: 64))
                .shadow(radius: 8)
            Text("PARCHEESI QUEST")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(white: 0.8)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            Text("Classic Strategy • Modern Fun")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.vertical, 20)
    }

    // MARK: - Mode Selector

    private var modeSelectorGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                GameModeButton(
                    icon: "person.2.fill",
                    title: "Pass & Play",
                    subtitle: "2–4 local players",
                    color: .green,
                    action: { startLocalGame() }
                )

                if FeatureFlags.shared.isAIEnabled {
                    GameModeButton(
                        icon: "cpu.fill",
                        title: "vs Computer",
                        subtitle: "3 difficulty levels",
                        color: .orange,
                        action: { startAIGame() }
                    )
                }
            }

            if FeatureFlags.shared.isOnlineMultiplayerEnabled {
                HStack(spacing: 12) {
                    GameModeButton(
                        icon: "globe.americas.fill",
                        title: "Online",
                        subtitle: "Matchmaking",
                        color: .blue,
                        action: {
                            lobbyVM.startMatchmaking(playerCount: 4)
                            navigateToLobby = true
                        }
                    )

                    GameModeButton(
                        icon: "lock.fill",
                        title: "Private Room",
                        subtitle: "Invite friends",
                        color: .purple,
                        action: {
                            navigateToLobby = true
                        }
                    )
                }
            }
        }
    }

    // MARK: - Bottom Action Row

    private var bottomActionRow: some View {
        HStack(spacing: 20) {
            if FeatureFlags.shared.isLeaderboardEnabled {
                IconActionButton(icon: "trophy.fill", label: "Ranks") {
                    showLeaderboard = true
                }
            }

            IconActionButton(icon: "person.crop.circle.fill", label: "Profile") {
                showProfile = true
            }

            IconActionButton(icon: "gearshape.fill", label: "Settings") {
                // Navigate to settings
            }
        }
    }

    // MARK: - Game Start Helpers

    private func startLocalGame() {
        let colors: [PlayerColor] = [.red, .blue, .green, .yellow]
        let players = (0..<2).map { i in
            Player(id: UUID().uuidString, displayName: "Player \(i + 1)", color: colors[i])
        }
        let state = GameState(mode: .localPassAndPlay, players: players)
        navigateToGame = state
    }

    private func startAIGame() {
        let humanPlayer = Player(
            id: AuthService.shared.currentUserID ?? UUID().uuidString,
            displayName: authViewModel.currentUser?.displayName ?? "You",
            color: .red
        )
        let ai1 = Player(id: UUID().uuidString, displayName: "Atlas",   color: .blue,   isAI: true, aiDifficulty: .medium)
        let ai2 = Player(id: UUID().uuidString, displayName: "Bolt",    color: .green,  isAI: true, aiDifficulty: .easy)
        let ai3 = Player(id: UUID().uuidString, displayName: "Magnus",  color: .yellow, isAI: true, aiDifficulty: .hard)
        let state = GameState(mode: .vsAI, players: [humanPlayer, ai1, ai2, ai3])
        navigateToGame = state
    }
}

// MARK: - Supporting Components

struct GameModeButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct IconActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }
}

struct CurrencyBadge: View {
    let icon: String
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 14))
            Text("\(value)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(.white.opacity(0.2)))
    }
}

struct XPBarView: View {
    let xp: Int
    let level: Int

    var progress: Double {
        let current = XPSystem.xpRequired(forLevel: level)
        let next = XPSystem.xpRequired(forLevel: level + 1)
        guard next > current else { return 1 }
        return min(1, Double(xp - current) / Double(next - current))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.3))
                Capsule()
                    .fill(Color.yellow)
                    .frame(width: geo.size.width * progress)
            }
        }
    }
}

struct AvatarView: View {
    let avatarID: String
    let size: CGFloat

    var body: some View {
        // In production, load from asset catalog or URL
        Circle()
            .fill(Color.accentColor.opacity(0.8))
            .frame(width: size, height: size)
            .overlay(
                Text(avatarID.prefix(1).uppercased())
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
}

struct AnimatedBackgroundView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.2, blue: 0.5),
                Color(red: 0.3, green: 0.1, blue: 0.5),
                Color(red: 0.1, green: 0.3, blue: 0.6)
            ],
            startPoint: UnitPoint(x: 0.2 + sin(phase) * 0.1, y: 0),
            endPoint: UnitPoint(x: 0.8 + cos(phase) * 0.1, y: 1)
        )
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: true)) {
                phase = .pi
            }
        }
    }
}
