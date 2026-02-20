// SettingsView.swift
// Full settings screen: audio, haptics, theme, notifications, privacy, account

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var audioService = AudioService.shared
    @StateObject private var hapticService = HapticService.shared
    @State private var showDeleteAccountAlert = false
    @State private var showSignOutAlert = false
    @State private var notificationsEnabled = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {

                // MARK: - Audio
                Section {
                    Toggle(isOn: $audioService.isSFXEnabled) {
                        Label("Sound Effects", systemImage: "speaker.wave.2.fill")
                    }
                    .onChange(of: audioService.isSFXEnabled) { _ in
                        if audioService.isSFXEnabled {
                            audioService.play(.buttonTap)
                        }
                    }

                    if audioService.isSFXEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Effects Volume", systemImage: "dial.medium")
                                .font(.subheadline)
                            Slider(value: $audioService.sfxVolume, in: 0...1) {
                                Text("Volume")
                            } minimumValueLabel: {
                                Image(systemName: "speaker")
                                    .font(.caption)
                            } maximumValueLabel: {
                                Image(systemName: "speaker.wave.3")
                                    .font(.caption)
                            }
                        }
                        .transition(.opacity)
                    }

                    Toggle(isOn: $audioService.isMusicEnabled) {
                        Label("Background Music", systemImage: "music.note")
                    }
                } header: {
                    Text("Audio")
                }

                // MARK: - Haptics
                Section {
                    Toggle(isOn: $hapticService.isEnabled) {
                        Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    .onChange(of: hapticService.isEnabled) { enabled in
                        if enabled { hapticService.trigger(.buttonTap) }
                    }

                    if hapticService.isEnabled {
                        Button {
                            hapticService.trigger(.capture)
                        } label: {
                            Label("Test Haptics", systemImage: "hand.tap")
                                .foregroundStyle(Color.accentColor)
                        }
                        .transition(.opacity)
                    }
                } header: {
                    Text("Haptics")
                }

                // MARK: - Appearance
                Section {
                    Picker("Color Scheme", selection: $themeManager.colorSchemePreference) {
                        Text("System").tag(ThemeManager.ColorSchemePreference.system)
                        Text("Light").tag(ThemeManager.ColorSchemePreference.light)
                        Text("Dark").tag(ThemeManager.ColorSchemePreference.dark)
                    }
                    .pickerStyle(.menu)

                    NavigationLink {
                        ThemePickerView()
                            .environmentObject(themeManager)
                    } label: {
                        HStack {
                            Label("Board Theme", systemImage: "paintbrush.fill")
                            Spacer()
                            Text(BoardTheme.all.first(where: { $0.id == themeManager.selectedThemeID })?.name ?? "Classic")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Appearance")
                }

                // MARK: - Notifications
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Push Notifications", systemImage: "bell.fill")
                    }
                    .onChange(of: notificationsEnabled) { enabled in
                        if enabled {
                            requestNotificationPermission()
                        } else {
                            openSystemSettings()
                        }
                    }
                    .onAppear {
                        checkNotificationStatus()
                    }

                    Button {
                        openSystemSettings()
                    } label: {
                        Label("Notification Settings", systemImage: "gear")
                            .foregroundStyle(Color.accentColor)
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Receive alerts for your turn, friend requests, and daily rewards.")
                }

                // MARK: - Gameplay
                Section {
                    NavigationLink {
                        GameplaySettingsView()
                    } label: {
                        Label("Gameplay Preferences", systemImage: "gamecontroller.fill")
                    }
                } header: {
                    Text("Gameplay")
                }

                // MARK: - Privacy & Support
                Section {
                    Link(destination: privacyPolicyURL) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                    Link(destination: termsURL) {
                        Label("Terms of Service", systemImage: "doc.text.fill")
                    }
                    Link(destination: supportURL) {
                        Label("Contact Support", systemImage: "envelope.fill")
                    }
                    NavigationLink {
                        AcknowledgementsView()
                    } label: {
                        Label("Acknowledgements", systemImage: "info.circle.fill")
                    }
                } header: {
                    Text("Legal & Support")
                }

                // MARK: - Account
                Section {
                    Button {
                        showSignOutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.red)
                    }

                    Button {
                        showDeleteAccountAlert = true
                    } label: {
                        Label("Delete Account", systemImage: "trash.fill")
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text("Deleting your account permanently removes all your data and cannot be undone.")
                }

                // MARK: - App Info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersionString)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(buildNumberString)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    authViewModel.signOut()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("This will permanently delete your account, stats, and purchases. This cannot be undone.")
            }
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                notificationsEnabled = granted
                if !granted { openSystemSettings() }
            }
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Account Deletion

    private func deleteAccount() {
        guard let uid = AuthService.shared.currentUserID else { return }
        Task {
            // Delete Firestore data (Cloud Function handles full cleanup)
            // Then delete Auth account
            do {
                try await AuthService.shared.currentUser?.delete()
                authViewModel.signOut()
                dismiss()
            } catch {
                // Re-authentication may be required — show re-auth flow
                print("[Settings] Account deletion error: \(error)")
            }
        }
    }

    // MARK: - URLs

    private var privacyPolicyURL: URL { URL(string: "https://yourcompany.com/privacy")! }
    private var termsURL: URL { URL(string: "https://yourcompany.com/terms")! }
    private var supportURL: URL { URL(string: "mailto:support@yourcompany.com")! }

    // MARK: - App Info

    private var appVersionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    private var buildNumberString: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

// MARK: - Gameplay Settings

struct GameplaySettingsView: View {

    @AppStorage("showHints") private var showHints = true
    @AppStorage("animationSpeed") private var animationSpeed = 1.0
    @AppStorage("confirmMoves") private var confirmMoves = false
    @AppStorage("autoRollAfterBonus") private var autoRollAfterBonus = true

    var body: some View {
        List {
            Section {
                Toggle("Show Move Hints", isOn: $showHints)
                Toggle("Confirm Before Moving", isOn: $confirmMoves)
                Toggle("Auto-Roll After Bonus", isOn: $autoRollAfterBonus)
            } header: {
                Text("Controls")
            } footer: {
                Text("'Confirm Before Moving' shows a confirmation step before executing a token move.")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Animation Speed")
                        Spacer()
                        Text(animationSpeedLabel)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    Slider(value: $animationSpeed, in: 0.5...2.0, step: 0.25) {
                        Text("Speed")
                    } minimumValueLabel: {
                        Text("Slow").font(.caption)
                    } maximumValueLabel: {
                        Text("Fast").font(.caption)
                    }
                }
            } header: {
                Text("Animations")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Gameplay")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var animationSpeedLabel: String {
        switch animationSpeed {
        case ..<0.75: return "Slow"
        case ..<1.25: return "Normal"
        case ..<1.75: return "Fast"
        default: return "Fastest"
        }
    }
}

// MARK: - Theme Picker

struct ThemePickerView: View {

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        List {
            ForEach(BoardTheme.all) { theme in
                let isUnlocked = authViewModel.currentUser?.unlockedThemeIDs.contains(theme.id) ?? false
                let isSelected = themeManager.selectedThemeID == theme.id

                Button {
                    guard isUnlocked else { return }
                    themeManager.selectedThemeID = theme.id
                    HapticService.shared.trigger(.buttonTap)
                } label: {
                    HStack(spacing: 16) {
                        // Theme preview swatch
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeGradient(for: theme.id))
                            .frame(width: 60, height: 44)
                            .overlay(
                                Text("🎲")
                                    .font(.title3)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(theme.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text(theme.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if !isUnlocked {
                                HStack(spacing: 4) {
                                    if theme.isPremiumOnly {
                                        Label("Premium", systemImage: "crown.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.yellow)
                                    } else if theme.coinPrice > 0 {
                                        Label("\(theme.coinPrice) coins", systemImage: "circle.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                                .font(.title3)
                        } else if !isUnlocked {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Board Theme")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func themeGradient(for id: String) -> LinearGradient {
        switch id {
        case "midnight": return LinearGradient(colors: [.black, Color(white: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "jungle":   return LinearGradient(colors: [Color(red: 0.1, green: 0.5, blue: 0.1), .green], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "ocean":    return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "neon":     return LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "golden":   return LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:         return LinearGradient(colors: [Color(red: 0.95, green: 0.88, blue: 0.75), Color(red: 0.8, green: 0.68, blue: 0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Acknowledgements

struct AcknowledgementsView: View {
    var body: some View {
        List {
            Section("Open Source Libraries") {
                AckRow(name: "Firebase iOS SDK", license: "Apache 2.0", url: "https://github.com/firebase/firebase-ios-sdk")
                AckRow(name: "Google Mobile Ads", license: "Proprietary", url: "https://admob.google.com")
            }
            Section("Game Rules") {
                Text("Parcheesi Quest is inspired by classic Parcheesi board game rules which are in the public domain. All artwork, branding, sounds, and game logic are original works created for this application.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Audio") {
                Text("Sound effects and music are original compositions or licensed from royalty-free sources. All rights reserved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AckRow: View {
    let name: String
    let license: String
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                Text(license)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
