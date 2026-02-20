// HapticService.swift
// Haptic feedback manager with game-specific patterns

import UIKit
import CoreHaptics

enum HapticPattern {
    case diceRoll
    case tokenMove
    case capture
    case tokenFinish
    case victory
    case buttonTap
    case error
}

final class HapticService: ObservableObject {

    static let shared = HapticService()
    private init() { prepareHaptics() }

    // MARK: - State

    var isEnabled: Bool = UserDefaults.standard.bool(forKey: "hapticsEnabled") {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "hapticsEnabled") }
    }

    // MARK: - Engines

    private var engine: CHHapticEngine?
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    // MARK: - Setup

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("[HapticService] Engine start error: \(error.localizedDescription)")
        }

        engine?.resetHandler = { [weak self] in
            do { try self?.engine?.start() } catch {}
        }
        engine?.stoppedHandler = { reason in
            print("[HapticService] Engine stopped: \(reason)")
        }

        // Set default for new install
        if !UserDefaults.standard.bool(forKey: "hapticsConfigured") {
            isEnabled = true
            UserDefaults.standard.set(true, forKey: "hapticsConfigured")
        }

        [impactLight, impactMedium, impactHeavy, notification, selection].forEach { ($0 as? UIFeedbackGenerator)?.prepare() }
    }

    // MARK: - Trigger

    func trigger(_ pattern: HapticPattern) {
        guard isEnabled else { return }
        switch pattern {
        case .buttonTap:   impactLight.impactOccurred()
        case .tokenMove:   impactMedium.impactOccurred()
        case .capture:     impactHeavy.impactOccurred(); playCustomCaptureHaptic()
        case .tokenFinish: notification.notificationOccurred(.success)
        case .victory:     playVictoryHaptic()
        case .diceRoll:    playDiceHaptic()
        case .error:       notification.notificationOccurred(.error)
        }
    }

    // MARK: - Custom Patterns

    private func playDiceHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine else {
            // Fallback
            impactLight.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.impactLight.impactOccurred() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { self.impactMedium.impactOccurred() }
            return
        }

        do {
            var events: [CHHapticEvent] = []
            for i in 0..<6 {
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(i) / 5.0)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                let event = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [intensity, sharpness],
                    relativeTime: Double(i) * 0.08
                )
                events.append(event)
            }
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[HapticService] Dice haptic error: \(error)")
        }
    }

    private func playCustomCaptureHaptic() {
        guard let engine else { return }
        do {
            let events: [CHHapticEvent] = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: 0.1,
                    duration: 0.2
                )
            ]
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {}
    }

    private func playVictoryHaptic() {
        // Escalating triumphant pattern
        let delays: [Double] = [0, 0.1, 0.2, 0.35, 0.55]
        for (i, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                if i < delays.count - 1 {
                    self?.impactMedium.impactOccurred()
                } else {
                    self?.impactHeavy.impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self?.notification.notificationOccurred(.success)
                    }
                }
            }
        }
    }
}
