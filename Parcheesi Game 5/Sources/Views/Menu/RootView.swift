// RootView.swift
// Root router: shows AuthView or MainMenuView based on auth state

import SwiftUI

struct RootView: View {

    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var appState: AppStateManager
    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
            } else if authViewModel.isAuthenticated {
                MainMenuView()
                    .transition(.opacity)
            } else {
                AuthView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: authViewModel.isAuthenticated)
        .animation(.easeInOut(duration: 0.5), value: showSplash)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { showSplash = false }
            }
        }
    }
}

// MARK: - Splash Screen

struct SplashScreenView: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.2, blue: 0.5),
                    Color(red: 0.3, green: 0.1, blue: 0.5)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("🎲")
                    .font(.system(size: 80))
                    .scaleEffect(scale)
                    .shadow(radius: 12)

                Text("PARCHEESI QUEST")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
            }
            withAnimation(.easeIn(duration: 0.6).delay(0.3)) {
                opacity = 1
            }
        }
    }
}

// MARK: - Daily Reward View

struct DailyRewardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var claimed = false
    let reward = DailyRewardManager.shared.currentReward

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("🎁")
                .font(.system(size: 72))

            Text("Daily Reward!")
                .font(.title.bold())

            Text("Day \(DailyRewardManager.shared.consecutiveDays) Streak")
                .font(.headline)
                .foregroundStyle(Color.accentColor)

            // Reward details
            VStack(spacing: 12) {
                if reward.coins > 0 {
                    RewardRow(icon: "🪙", value: "+\(reward.coins)", label: "Coins")
                }
                if reward.gems > 0 {
                    RewardRow(icon: "💎", value: "+\(reward.gems)", label: "Gems")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.accentColor.opacity(0.1))
            )
            .padding(.horizontal, 32)

            Spacer()

            Button {
                DailyRewardManager.shared.claimReward()
                claimed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    dismiss()
                }
            } label: {
                Group {
                    if claimed {
                        Label("Claimed!", systemImage: "checkmark.circle.fill")
                    } else {
                        Text("Claim Reward")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Capsule().fill(claimed ? Color.green : Color.accentColor))
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
            .disabled(claimed)
        }
    }
}

struct RewardRow: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack {
            Text(icon)
                .font(.title2)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(Color.accentColor)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Leaderboard View (placeholder)

struct LeaderboardView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(1...10, id: \.self) { rank in
                    HStack {
                        Text("\(rank)")
                            .font(.headline)
                            .frame(width: 32)
                            .foregroundStyle(rank <= 3 ? Color.yellow : .primary)
                        AvatarView(avatarID: "default", size: 36)
                        VStack(alignment: .leading) {
                            Text("Player \(rank)")
                                .font(.system(size: 15, weight: .medium))
                            Text("Level \(30 - rank * 2)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(1000 - rank * 80) XP")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
