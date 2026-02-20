// ThemeManager.swift
// Manages UI theme selection and dark mode preference

import SwiftUI
import Combine

final class ThemeManager: ObservableObject {

    @Published var selectedThemeID: String = UserDefaults.standard.string(forKey: "selectedThemeID") ?? "classic" {
        didSet {
            UserDefaults.standard.set(selectedThemeID, forKey: "selectedThemeID")
        }
    }

    @Published var colorSchemePreference: ColorSchemePreference = {
        let raw = UserDefaults.standard.string(forKey: "colorScheme") ?? "system"
        return ColorSchemePreference(rawValue: raw) ?? .system
    }() {
        didSet {
            UserDefaults.standard.set(colorSchemePreference.rawValue, forKey: "colorScheme")
        }
    }

    enum ColorSchemePreference: String {
        case light, dark, system
    }

    var colorScheme: ColorScheme? {
        switch colorSchemePreference {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
    }

    var currentTheme: BoardThemeConfig {
        switch selectedThemeID {
        case "midnight": return .midnight
        default:         return .classic
        }
    }
}
