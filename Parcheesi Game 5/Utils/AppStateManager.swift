// AppStateManager.swift
// Top-level app state coordination

import Foundation
import Combine

final class AppStateManager: ObservableObject {

    @Published var isOnline: Bool = true
    @Published var maintenanceMode: Bool = false
    @Published var forceUpdateRequired: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        checkNetworkReachability()
        checkMaintenanceStatus()
    }

    private func checkNetworkReachability() {
        // In production, integrate NWPathMonitor
        NotificationCenter.default.publisher(for: .init("NetworkStatusChanged"))
            .sink { [weak self] notification in
                self?.isOnline = notification.userInfo?["online"] as? Bool ?? true
            }
            .store(in: &cancellables)
    }

    private func checkMaintenanceStatus() {
        Task {
            let flags = FeatureFlags.shared
            await MainActor.run {
                // maintenance_mode and force_update_version are fetched via Remote Config
                // already handled in FeatureFlags.loadRemoteConfig()
            }
        }
    }
}
