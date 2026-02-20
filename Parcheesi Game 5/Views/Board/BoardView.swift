// BoardView.swift
// Main SpriteKit-backed game board rendered inside SwiftUI

import SwiftUI
import SpriteKit

struct BoardView: View {

    @ObservedObject var viewModel: GameViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showChat = false

    var body: some View {
        ZStack {
            // SpriteKit Board Scene
            SpriteView(scene: makeBoardScene())
                .ignoresSafeArea()

            // HUD overlay
            VStack(spacing: 0) {
                // Top HUD: player indicators
                PlayerHUDView(viewModel: viewModel)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                Spacer()

                // Bottom HUD: dice and action buttons
                BottomHUDView(viewModel: viewModel)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }

            // Turn timer ring (online modes only)
            if viewModel.gameState.mode == .onlineMultiplayer || viewModel.gameState.mode == .privateRoom {
                TurnTimerView(remaining: viewModel.turnTimeRemaining,
                              total: FeatureFlags.shared.turnTimerSeconds)
                    .frame(width: 48, height: 48)
                    .position(x: UIScreen.main.bounds.width - 40, y: 60)
            }

            // Capture flash overlay
            if let flashColor = viewModel.showCaptureFlash {
                CaptureFlashView(color: flashColor.swiftUIColor)
            }

            // Toast
            if let toast = viewModel.toastMessage {
                ToastView(message: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(), value: viewModel.toastMessage)
                    .padding(.top, 120)
            }

            // Chat button
            if FeatureFlags.shared.isChatEnabled {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            showChat.toggle()
                        } label: {
                            Image(systemName: "message.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(Circle().fill(Color.accentColor))
                                .shadow(radius: 4)
                        }
                        .padding([.trailing, .top], 16)
                    }
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showChat) {
            ChatView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $viewModel.showWinScreen) {
            if let winner = viewModel.winner {
                WinScreen(winner: winner, gameState: viewModel.gameState)
            }
        }
    }

    // MARK: - Scene Factory

    private func makeBoardScene() -> BoardScene {
        let scene = BoardScene(size: UIScreen.main.bounds.size)
        scene.scaleMode = .resizeFill
        scene.gameViewModel = viewModel
        scene.theme = themeManager.currentTheme
        return scene
    }
}

// MARK: - Player HUD

private struct PlayerHUDView: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(viewModel.gameState.players.enumerated()), id: \.offset) { idx, player in
                PlayerIndicator(
                    player: player,
                    isActive: idx == viewModel.gameState.currentPlayerIndex,
                    finishedCount: player.finishedTokenCount
                )
            }
        }
    }
}

private struct PlayerIndicator: View {
    let player: Player
    let isActive: Bool
    let finishedCount: Int

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(player.color.swiftUIColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(isActive ? Color.white : Color.clear, lineWidth: 3)
                    )
                    .shadow(color: isActive ? player.color.swiftUIColor.opacity(0.8) : .clear, radius: 8)

                Text("\(finishedCount)/4")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(player.displayName)
                .font(.caption2)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: 60)
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(isActive ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isActive)
    }
}

// MARK: - Bottom HUD

private struct BottomHUDView: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        HStack(spacing: 20) {
            // Dice display
            if let dice = viewModel.gameState.currentDice {
                DiceDisplayView(dice: dice, animating: viewModel.diceAnimating)
            } else {
                Spacer()
            }

            Spacer()

            // Roll button
            if viewModel.gameState.phase == .rolling && viewModel.isMyTurn {
                Button {
                    viewModel.rollDice()
                } label: {
                    Label("Roll Dice", systemImage: "dice.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Color.accentColor))
                        .shadow(radius: 6)
                }
                .disabled(viewModel.diceAnimating)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Dice Display

struct DiceDisplayView: View {
    let dice: DiceResult
    let animating: Bool

    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            SingleDieView(value: dice.die1)
            SingleDieView(value: dice.die2)
        }
        .rotationEffect(.degrees(animating ? rotation : 0))
        .onChange(of: animating) { isAnimating in
            if isAnimating {
                withAnimation(.linear(duration: 0.1).repeatCount(8)) {
                    rotation = 360
                }
            } else {
                rotation = 0
            }
        }
    }
}

struct SingleDieView: View {
    let value: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
                .frame(width: 44, height: 44)
                .shadow(radius: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            DiePipsView(value: value)
        }
    }
}

struct DiePipsView: View {
    let value: Int

    var body: some View {
        let layout = pipLayout(for: value)
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                  spacing: 4) {
            ForEach(0..<9, id: \.self) { pos in
                Circle()
                    .fill(layout.contains(pos) ? Color.primary : Color.clear)
                    .frame(width: 7, height: 7)
            }
        }
        .padding(6)
    }

    private func pipLayout(for value: Int) -> Set<Int> {
        switch value {
        case 1: return [4]
        case 2: return [2, 6]
        case 3: return [2, 4, 6]
        case 4: return [0, 2, 6, 8]
        case 5: return [0, 2, 4, 6, 8]
        case 6: return [0, 2, 3, 5, 6, 8]
        default: return []
        }
    }
}

// MARK: - Turn Timer

struct TurnTimerView: View {
    let remaining: Int
    let total: Int

    var progress: Double { Double(remaining) / Double(total) }
    var isUrgent: Bool { remaining <= 10 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(isUrgent ? Color.red : Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: remaining)
            Text("\(remaining)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isUrgent ? .red : .primary)
        }
        .background(Circle().fill(.background).shadow(radius: 4))
    }
}

// MARK: - Capture Flash

struct CaptureFlashView: View {
    let color: Color
    @State private var opacity = 0.0

    var body: some View {
        Rectangle()
            .fill(color.opacity(opacity))
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeIn(duration: 0.15)) { opacity = 0.4 }
                withAnimation(.easeOut(duration: 0.4).delay(0.15)) { opacity = 0 }
            }
            .allowsHitTesting(false)
    }
}

// MARK: - Toast

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.black.opacity(0.75)))
            .shadow(radius: 4)
    }
}
