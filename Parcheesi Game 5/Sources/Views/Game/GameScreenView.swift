// GameScreenView.swift
// Container that wraps the board and provides navigation + pause controls

import SwiftUI
import SpriteKit

struct GameScreenView: View {

    let gameState: GameState
    @StateObject private var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showPauseMenu = false
    @State private var showResignAlert = false

    init(gameState: GameState) {
        self.gameState = gameState
        let networkService: MultiplayerNetworkService? = {
            switch gameState.mode {
            case .onlineMultiplayer, .privateRoom:
                return MultiplayerNetworkService.shared
            default:
                return nil
            }
        }()
        _viewModel = StateObject(wrappedValue: GameViewModel(
            gameState: gameState,
            networkService: networkService
        ))
    }

    var body: some View {
        ZStack {
            BoardView(viewModel: viewModel)

            // Pause button (top-left)
            VStack {
                HStack {
                    Button {
                        showPauseMenu = true
                    } label: {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.85))
                            .shadow(radius: 4)
                    }
                    .padding(16)
                    Spacer()
                }
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showPauseMenu) {
            PauseMenuView(
                gameState: viewModel.gameState,
                onResume: { showPauseMenu = false },
                onResign: {
                    showPauseMenu = false
                    showResignAlert = true
                }
            )
            .presentationDetents([.medium])
        }
        .alert("Resign Game?", isPresented: $showResignAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Resign", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("Your opponents will win. Are you sure?")
        }
        .statusBarHidden()
    }
}

// MARK: - Pause Menu

struct PauseMenuView: View {
    let gameState: GameState
    let onResume: () -> Void
    let onResign: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Resume Game") {
                        onResume()
                    }
                    .foregroundStyle(Color.accentColor)
                    .fontWeight(.bold)
                }

                Section("Players") {
                    ForEach(gameState.players) { player in
                        HStack {
                            Circle()
                                .fill(player.color.swiftUIColor)
                                .frame(width: 16, height: 16)
                            Text(player.displayName)
                            Spacer()
                            Text("\(player.finishedTokenCount)/4 home")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Board Theme") {
                    Picker("Theme", selection: $themeManager.selectedThemeID) {
                        ForEach(BoardTheme.all) { theme in
                            Text(theme.name).tag(theme.id)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button("Resign", role: .destructive) {
                        onResign()
                    }
                }
            }
            .navigationTitle("Game Paused")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Win Screen

struct WinScreen: View {
    let winner: Player
    let gameState: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var showConfetti = true

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 24) {
                Spacer()

                // Trophy
                Text("🏆")
                    .font(.system(size: 80))
                    .shadow(radius: 12)

                // Winner announcement
                VStack(spacing: 8) {
                    Text("WINNER!")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(winner.displayName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(winner.color.swiftUIColor)
                }

                // Stats summary
                gameStatsSummary

                Spacer()

                // Actions
                VStack(spacing: 12) {
                    Button {
                        // Rematch logic
                        dismiss()
                    } label: {
                        Text("Play Again")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(Color.accentColor))
                    }
                    .padding(.horizontal, 32)

                    Button {
                        dismiss()
                    } label: {
                        Text("Main Menu")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    private var gameStatsSummary: some View {
        VStack(spacing: 12) {
            Text("Game Summary")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 24) {
                StatPill(label: "Turns", value: "\(gameState.turnNumber)")
                StatPill(label: "Captures", value: "\(gameState.captureHistory.count)")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.1))
        )
        .padding(.horizontal, 32)
    }
}

struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

// MARK: - Confetti (lightweight SpriteKit confetti)

struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> SKView {
        let view = SKView(frame: UIScreen.main.bounds)
        view.backgroundColor = .clear
        view.allowsTransparency = true
        let scene = ConfettiScene(size: UIScreen.main.bounds.size)
        scene.backgroundColor = .clear
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
        return view
    }
    func updateUIView(_ uiView: SKView, context: Context) {}
}

final class ConfettiScene: SKScene {
    override func didMove(to view: SKView) {
        let colors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemYellow, .systemPurple, .systemOrange]
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 60
        emitter.numParticlesToEmit = 200
        emitter.particleLifetime = 4
        emitter.particleLifetimeRange = 2
        emitter.particlePositionRange = CGVector(dx: size.width, dy: 0)
        emitter.position = CGPoint(x: size.width / 2, y: size.height)
        emitter.particleSpeed = 200
        emitter.particleSpeedRange = 100
        emitter.particleAlpha = 1
        emitter.particleAlphaRange = 0.3
        emitter.particleScale = 0.15
        emitter.particleScaleRange = 0.1
        emitter.emissionAngle = CGFloat(270).degreesToRadians
        emitter.emissionAngleRange = CGFloat(60).degreesToRadians
        emitter.particleColor = colors.randomElement()!
        addChild(emitter)
    }
}

extension CGFloat {
    var degreesToRadians: CGFloat { self * .pi / 180 }
}
