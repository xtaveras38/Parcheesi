// AppDelegate.swift
// ParcheesiGame
// Production-ready AppDelegate with Firebase, notifications, and lifecycle management

import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate {

    // MARK: - Application Launch

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        configureFirebase()
        configurePushNotifications(application)
        configureAppearance()
        FeatureFlags.shared.loadRemoteConfig()
        AnalyticsService.shared.trackAppLaunch()
        return true
    }

    // MARK: - Private Configuration

    private func configureFirebase() {
        FirebaseApp.configure()
        FirebaseConfiguration.shared.setLoggerLevel(.min)
    }

    private func configurePushNotifications(_ application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if let error = error {
                print("[Notifications] Authorization error: \(error.localizedDescription)")
            }
            AnalyticsService.shared.track(event: "notification_permission", properties: ["granted": granted])
        }
        application.registerForRemoteNotifications()
    }

    private func configureAppearance() {
        // Global navigation bar styling
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(named: "NavBarBackground") ?? .systemBackground
        navBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(named: "PrimaryText") ?? .label,
            .font: UIFont.systemFont(ofSize: 18, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
    }

    // MARK: - Remote Notifications

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[Notifications] Failed to register: \(error.localizedDescription)")
    }

    // MARK: - Background/Foreground Lifecycle

    func applicationDidEnterBackground(_ application: UIApplication) {
        GameStateManager.shared.saveCurrentState()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        GameStateManager.shared.checkForPendingReconnect()
        DailyRewardManager.shared.checkDailyReward()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        GameStateManager.shared.saveCurrentState()
        AnalyticsService.shared.flush()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        NotificationRouter.shared.route(userInfo: userInfo)
        completionHandler()
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        NotificationService.shared.updateFCMToken(token)
    }
}
