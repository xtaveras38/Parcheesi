// AnalyticsService.swift
// Analytics event tracking (Firebase Analytics + custom backend)

import Foundation
import FirebaseAnalytics

final class AnalyticsService {

    static let shared = AnalyticsService()
    private init() {}

    // MARK: - App Events

    func trackAppLaunch() {
        track(event: "app_launch", properties: [
            "app_version": appVersion,
            "os_version": osVersion,
            "device_model": deviceModel
        ])
    }

    // MARK: - Generic Tracking

    func track(event: String, properties: [String: Any] = [:]) {
        var params: [String: Any] = properties
        params["timestamp"] = Date().timeIntervalSince1970
        params["user_id"] = AuthService.shared.currentUserID ?? "guest"

        // Firebase Analytics
        Analytics.logEvent(event, parameters: params.mapValues { "\($0)" })

        // Optional: send to custom backend
        sendToCustomBackend(event: event, properties: params)
    }

    // MARK: - User Properties

    func setUserID(_ userID: String) {
        Analytics.setUserID(userID)
    }

    func setUserProperty(_ value: String, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    // MARK: - Screen Tracking

    func trackScreen(_ name: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: name
        ])
    }

    // MARK: - Revenue Tracking

    func trackPurchase(productID: String, price: Decimal, currency: String = "USD") {
        Analytics.logEvent(AnalyticsEventPurchase, parameters: [
            AnalyticsParameterItemID: productID,
            AnalyticsParameterValue: NSDecimalNumber(decimal: price),
            AnalyticsParameterCurrency: currency
        ])
    }

    // MARK: - Flush

    func flush() {
        // Firebase Analytics auto-batches; no explicit flush needed
    }

    // MARK: - Custom Backend (optional)

    private func sendToCustomBackend(event: String, properties: [String: Any]) {
        // Implement POST to your analytics endpoint if needed
        // Batching and retry should be implemented for production
    }

    // MARK: - Device Info

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private var osVersion: String {
        UIDevice.current.systemVersion
    }

    private var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { id, element in
            guard let value = element.value as? Int8, value != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(value)))
        }
    }
}
