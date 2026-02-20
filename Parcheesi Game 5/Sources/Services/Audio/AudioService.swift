// AudioService.swift
// Sound effect and music playback manager using AVFoundation

import AVFoundation
import Combine

enum SoundEffect: String {
    case diceRoll     = "dice_roll"
    case tokenMove    = "token_move"
    case capture      = "capture"
    case tokenFinish  = "token_finish"
    case victory      = "victory"
    case buttonTap    = "button_tap"
    case chatReceive  = "chat_receive"
    case countdown    = "countdown"
    case matchFound   = "match_found"
}

final class AudioService: ObservableObject {

    static let shared = AudioService()
    private init() { setupAudioSession() }

    // MARK: - Published

    @Published var isSFXEnabled: Bool = UserDefaults.standard.bool(forKey: "sfxEnabled") {
        didSet { UserDefaults.standard.set(isSFXEnabled, forKey: "sfxEnabled") }
    }

    @Published var isMusicEnabled: Bool = UserDefaults.standard.bool(forKey: "musicEnabled") {
        didSet {
            UserDefaults.standard.set(isMusicEnabled, forKey: "musicEnabled")
            isMusicEnabled ? playBackgroundMusic() : stopBackgroundMusic()
        }
    }

    @Published var sfxVolume: Float = UserDefaults.standard.float(forKey: "sfxVolume") {
        didSet { UserDefaults.standard.set(sfxVolume, forKey: "sfxVolume") }
    }

    // MARK: - Private

    private var players: [String: AVAudioPlayer] = [:]
    private var musicPlayer: AVAudioPlayer?
    private let queue = DispatchQueue(label: "audio.service", qos: .userInteractive)

    // MARK: - Setup

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[AudioService] Session setup error: \(error.localizedDescription)")
        }
        // Default values
        if !UserDefaults.standard.bool(forKey: "audioConfigured") {
            isSFXEnabled = true
            isMusicEnabled = true
            sfxVolume = 0.8
            UserDefaults.standard.set(true, forKey: "audioConfigured")
        }
    }

    // MARK: - Sound Effects

    func play(_ sound: SoundEffect) {
        guard isSFXEnabled else { return }
        queue.async { [weak self] in
            self?.playSoundOnQueue(named: sound.rawValue)
        }
    }

    private func playSoundOnQueue(named name: String) {
        // Look for .mp3 then .wav in the bundle
        let ext = ["mp3", "wav", "caf"]
        var url: URL?
        for e in ext {
            if let u = Bundle.main.url(forResource: name, withExtension: e) {
                url = u; break
            }
        }
        guard let soundURL = url else {
            // Synthesize a simple beep as fallback during development
            AudioServicesPlaySystemSound(1104)
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: soundURL)
            player.volume = sfxVolume
            player.prepareToPlay()
            players[name] = player
            player.play()
        } catch {
            print("[AudioService] Playback error: \(error.localizedDescription)")
        }
    }

    // MARK: - Background Music

    func playBackgroundMusic() {
        guard isMusicEnabled else { return }
        guard let url = Bundle.main.url(forResource: "background_music", withExtension: "mp3") else { return }
        do {
            musicPlayer = try AVAudioPlayer(contentsOf: url)
            musicPlayer?.numberOfLoops = -1
            musicPlayer?.volume = 0.35
            musicPlayer?.play()
        } catch {
            print("[AudioService] Music error: \(error.localizedDescription)")
        }
    }

    func stopBackgroundMusic() {
        musicPlayer?.stop()
        musicPlayer = nil
    }

    func pauseBackgroundMusic() {
        musicPlayer?.pause()
    }

    func resumeBackgroundMusic() {
        guard isMusicEnabled else { return }
        musicPlayer?.play()
    }
}
