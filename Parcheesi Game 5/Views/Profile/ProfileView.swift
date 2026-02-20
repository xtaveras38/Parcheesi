// ProfileView.swift
// Full profile screen with stats, avatar, friends, and settings

import SwiftUI
import PhotosUI

struct ProfileView: View {

    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var profileVM = ProfileViewModel()
    @State private var showAvatarPicker = false
    @State private var showThemePicker = false
    @State private var showEditName = false
    @State private var editNameText = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showSignOutAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if profileVM.isLoading && profileVM.profile == nil {
                    ProgressView("Loading profile...")
                } else if let profile = profileVM.profile {
                    profileContent(profile: profile)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out", role: .destructive) {
                        showSignOutAlert = true
                    }
                    .tint(.red)
                }
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) { authViewModel.signOut() }
            }
        }
        .task {
            if let uid = AuthService.shared.currentUserID {
                await profileVM.loadProfile(userID: uid)
            }
        }
        .onChange(of: selectedPhotoItem) { item in
            guard let item else { return }
            Task { await profileVM.uploadAvatar(from: item) }
        }
    }

    // MARK: - Profile Content

    @ViewBuilder
    private func profileContent(profile: UserProfile) -> some View {
        List {
            // Avatar & name header
            Section {
                VStack(spacing: 16) {
                    // Avatar
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            AvatarView(avatarID: profile.selectedAvatarID, size: 96)
                                .overlay(Circle().stroke(Color.accentColor, lineWidth: 3))

                            Image(systemName: "camera.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Circle().fill(Color.accentColor))
                        }
                    }

                    // Name
                    HStack {
                        Text(profile.displayName)
                            .font(.title2.bold())
                        Button {
                            editNameText = profile.displayName
                            showEditName = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Level & XP
                    VStack(spacing: 6) {
                        HStack {
                            Text("Level \(profile.level)")
                                .font(.headline)
                                .foregroundStyle(Color.accentColor)
                            Spacer()
                            Text("\(profile.xp) XP")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        XPBarView(xp: profile.xp, level: profile.level)
                            .frame(height: 10)
                        Text("\(XPSystem.xpRequired(forLevel: profile.level + 1) - profile.xp) XP to Level \(profile.level + 1)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Currency
                    HStack(spacing: 20) {
                        CurrencyDisplay(icon: "🪙", value: profile.coins, label: "Coins")
                        CurrencyDisplay(icon: "💎", value: profile.gems, label: "Gems")
                        if profile.isPremium {
                            CurrencyDisplay(icon: "⭐", value: nil, label: "Premium")
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)

            // Stats
            Section("Game Stats") {
                statsGrid(stats: profile.stats)
            }

            // Friends
            if FeatureFlags.shared.isFriendSystemEnabled {
                Section("Friends (\(profileVM.friends.count))") {
                    if profileVM.pendingRequests.isEmpty == false {
                        ForEach(profileVM.pendingRequests) { req in
                            FriendRequestRow(request: req,
                                            onAccept: { Task { await profileVM.acceptFriendRequest(req) } },
                                            onDecline: { Task { await profileVM.declineFriendRequest(req) } })
                        }
                    }
                    ForEach(profileVM.friends) { friend in
                        FriendRow(friend: friend,
                                  onRemove: { Task { await profileVM.removeFriend(userID: friend.id) } })
                    }
                    if profileVM.friends.isEmpty && profileVM.pendingRequests.isEmpty {
                        Text("No friends yet. Invite someone!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Avatars
            Section("Avatars") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AvatarDefinition.all) { avatar in
                            AvatarSelectionItem(
                                avatar: avatar,
                                isSelected: profile.selectedAvatarID == avatar.id,
                                isUnlocked: profile.unlockedAvatarIDs.contains(avatar.id),
                                onTap: {
                                    if profile.unlockedAvatarIDs.contains(avatar.id) {
                                        Task { await profileVM.selectAvatar(id: avatar.id) }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(.insetGrouped)
        .alert("Edit Name", isPresented: $showEditName) {
            TextField("Display Name", text: $editNameText)
            Button("Save") { Task { await profileVM.updateDisplayName(editNameText) } }
            Button("Cancel", role: .cancel) {}
        }
        .errorAlert(message: $profileVM.errorMessage)
    }

    // MARK: - Stats Grid

    private func statsGrid(stats: GameStats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(label: "Games", value: "\(stats.totalGames)")
            StatCard(label: "Wins", value: "\(stats.wins)")
            StatCard(label: "Win Rate", value: String(format: "%.0f%%", stats.winRate * 100))
            StatCard(label: "Best Streak", value: "\(stats.bestStreak)")
            StatCard(label: "Captures", value: "\(stats.totalTokensCaptured)")
            StatCard(label: "Current Streak", value: "\(stats.currentStreak) 🔥")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Views

struct CurrencyDisplay: View {
    let icon: String
    let value: Int?
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(icon)
            if let value {
                Text("\(value)")
                    .font(.system(size: 15, weight: .bold))
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct StatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

struct FriendRow: View {
    let friend: UserProfile
    let onRemove: () -> Void

    var body: some View {
        HStack {
            AvatarView(avatarID: friend.selectedAvatarID, size: 40)
            VStack(alignment: .leading) {
                Text(friend.displayName)
                    .font(.system(size: 15, weight: .medium))
                Text("Level \(friend.level)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Remove", role: .destructive) { onRemove() }
                .font(.caption)
                .buttonStyle(.bordered)
        }
    }
}

struct FriendRequestRow: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(request.senderName)
                    .font(.system(size: 14, weight: .medium))
                Text("Friend Request")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Accept") { onAccept() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            Button("Decline") { onDecline() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }
}

struct AvatarSelectionItem: View {
    let avatar: AvatarDefinition
    let isSelected: Bool
    let isUnlocked: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                Text(String(avatar.imageName.prefix(1)).uppercased())
                    .font(.title2.bold())
                    .foregroundStyle(isUnlocked ? .primary : .secondary)
                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 56, height: 56, alignment: .bottomTrailing)
                        .font(.caption)
                }
            }
            Text(avatar.name)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .onTapGesture { onTap() }
    }
}

// MARK: - Error Alert Extension

extension View {
    func errorAlert(message: Binding<String?>) -> some View {
        alert("Error", isPresented: .constant(message.wrappedValue != nil)) {
            Button("OK") { message.wrappedValue = nil }
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
