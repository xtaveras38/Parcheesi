// LobbyView.swift
// Online lobby: create private room, join with code, or matchmaking

import SwiftUI

struct LobbyView: View {

    @ObservedObject var viewModel: LobbyViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var joinCode = ""
    @State private var showCreateOptions = false
    @State private var selectedPlayerCount = 4

    var body: some View {
        NavigationStack {
            Group {
                if let room = viewModel.currentRoom {
                    RoomLobbyView(viewModel: viewModel, room: room)
                } else if viewModel.isSearchingForMatch {
                    matchmakingView
                } else {
                    lobbyOptionsView
                }
            }
            .navigationTitle("Online Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") {
                        viewModel.cancelMatchmaking()
                        dismiss()
                    }
                }
            }
            .navigationDestination(item: $viewModel.navigateToGame) { state in
                GameScreenView(gameState: state)
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Options Screen

    private var lobbyOptionsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Matchmaking section
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Quick Match", icon: "bolt.fill")

                    Picker("Players", selection: $selectedPlayerCount) {
                        Text("2 Players").tag(2)
                        Text("3 Players").tag(3)
                        Text("4 Players").tag(4)
                    }
                    .pickerStyle(.segmented)

                    Button {
                        viewModel.startMatchmaking(playerCount: selectedPlayerCount)
                    } label: {
                        Label("Find Match", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Capsule().fill(Color.accentColor))
                            .foregroundStyle(.white)
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(.regularMaterial)
                )

                // Private Room section
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Private Room", icon: "lock.fill")

                    Picker("Players", selection: $selectedPlayerCount) {
                        Text("2").tag(2)
                        Text("3").tag(3)
                        Text("4").tag(4)
                    }
                    .pickerStyle(.segmented)

                    Button {
                        Task { await viewModel.createPrivateRoom(playerCount: selectedPlayerCount) }
                    } label: {
                        Label("Create Room", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Capsule().fill(Color.purple))
                            .foregroundStyle(.white)
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(.regularMaterial)
                )

                // Join with code section
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Join Room", icon: "ticket.fill")

                    HStack {
                        TextField("Enter room code", text: $joinCode)
                            .textFieldStyle(.plain)
                            .textCase(.uppercase)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.tertiarySystemBackground))
                            )

                        Button {
                            Task { await viewModel.joinRoom(code: joinCode) }
                        } label: {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(joinCode.count == 6 ? Color.accentColor : .secondary)
                        }
                        .disabled(joinCode.count < 6)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(.regularMaterial)
                )
            }
            .padding()
        }
    }

    // MARK: - Matchmaking Screen

    private var matchmakingView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated spinner
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.accentColor.opacity(0.3 + Double(i) * 0.2), lineWidth: 2)
                        .frame(width: CGFloat(60 + i * 30), height: CGFloat(60 + i * 30))
                }
                Image(systemName: "dice.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 140, height: 140)

            VStack(spacing: 8) {
                Text("Finding Match...")
                    .font(.title2.bold())
                Text("Elapsed: \(viewModel.matchmakingElapsed)s")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Connecting you with \(selectedPlayerCount - 1) opponent(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.cancelMatchmaking()
            } label: {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Capsule().fill(Color(.tertiarySystemBackground)))
                    .foregroundStyle(.red)
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(Color.accentColor)
    }
}

// MARK: - Room Lobby (Waiting Room)

struct RoomLobbyView: View {
    @ObservedObject var viewModel: LobbyViewModel
    let room: GameRoom

    var body: some View {
        VStack(spacing: 24) {
            // Invite code card
            if room.isPrivate {
                VStack(spacing: 8) {
                    Text("Room Code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(room.inviteCode)
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentColor.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                                )
                        )
                    Button {
                        UIPasteboard.general.string = room.inviteCode
                    } label: {
                        Label("Copy Code", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
            }

            // Player list
            VStack(alignment: .leading, spacing: 12) {
                Text("Players (\(room.players.count)/\(room.maxPlayers))")
                    .font(.headline)

                ForEach(room.players) { player in
                    HStack {
                        Circle()
                            .fill(player.color.swiftUIColor)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(player.displayName.prefix(1))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                        Text(player.displayName)
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                        if player.id == room.hostPlayerID {
                            Label("Host", systemImage: "crown.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }
                }

                // Empty slots
                ForEach(room.players.count..<room.maxPlayers, id: \.self) { _ in
                    HStack {
                        Circle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 36, height: 36)
                        Text("Waiting for player...")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))

            Spacer()

            // Start / Leave buttons
            VStack(spacing: 12) {
                if room.hostPlayerID == AuthService.shared.currentUserID {
                    Button {
                        Task { await viewModel.startGame() }
                    } label: {
                        Text(room.canStart ? "Start Game" : "Waiting for players...")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Capsule().fill(room.canStart ? Color.accentColor : Color.secondary))
                            .foregroundStyle(.white)
                            .font(.system(size: 16, weight: .bold))
                    }
                    .disabled(!room.canStart)
                } else {
                    Text("Waiting for host to start...")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                Button {
                    Task { await viewModel.leaveRoom() }
                } label: {
                    Text("Leave Room")
                        .foregroundStyle(.red)
                }
            }
        }
        .padding()
    }
}
