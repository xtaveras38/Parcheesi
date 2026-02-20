// ParcheesiGameApp.swift
// Main SwiftUI App entry point with environment setup

import SwiftUI
import Firebase

@main
struct ParcheesiGameApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppStateManager()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(authViewModel)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    GameStateManager.shared.saveCurrentState()
                }
        }
    }
}
