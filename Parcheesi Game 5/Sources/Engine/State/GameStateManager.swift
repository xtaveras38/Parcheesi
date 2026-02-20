// GameStateManager.swift
// Manages game state persistence, save/load, and reconnect logic

import Foundation
import Combine

final class GameStateManager: ObservableObject {

    static let shared = GameStateManager()

    // MARK: - Published State

    @Published var currentGameState: GameState?
    @Published var isReconnecting: Bool = false

    // MARK: - Private

    private let saveKey = "parcheesi_current_game"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var cancellables = Set<AnyCancellable>()

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Save / Load

    func saveCurrentState() {
        guard let state = currentGameState else { return }
        do {
            let data = try encoder.encode(state)
            UserDefaults.standard.set(data, forKey: saveKey)
        } catch {
            print("[GameStateManager] Save error: \(error.localizedDescription)")
        }
    }

    func loadSavedState() -> GameState? {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return nil }
        do {
            return try decoder.decode(GameState.self, from: data)
        } catch {
            print("[GameStateManager] Load error: \(error.localizedDescription)")
            return nil
        }
    }

    func clearSavedState() {
        UserDefaults.standard.removeObject(forKey: saveKey)
        currentGameState = nil
    }

    // MARK: - Reconnect

    func checkForPendingReconnect() {
        guard let saved = loadSavedState() else { return }
        // Only reconnect for online modes
        guard saved.mode == .onlineMultiplayer || saved.mode == .privateRoom else { return }
        // Only reconnect if the game was recent (within 30 minutes)
        guard Date().timeIntervalSince(saved.updatedAt) < 1800 else {
            clearSavedState()
            return
        }
        isReconnecting = true
        currentGameState = saved
    }

    // MARK: - Snapshot Sync (Firebase -> Local)

    /// Update the local state from a Firebase snapshot dict
    func updateFromFirebase(_ dict: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: dict)
            let state = try decoder.decode(GameState.self, from: data)
            DispatchQueue.main.async { [weak self] in
                self?.currentGameState = state
            }
        } catch {
            print("[GameStateManager] Firebase parse error: \(error.localizedDescription)")
        }
    }

    /// Serialize current state for Firebase upload
    func toFirebaseDict() -> [String: Any]? {
        guard let state = currentGameState else { return nil }
        do {
            let data = try encoder.encode(state)
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            return nil
        }
    }
}
