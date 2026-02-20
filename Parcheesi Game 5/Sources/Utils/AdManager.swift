// AdManager.swift
// Rewarded ad integration via Google AdMob

import Foundation
import GoogleMobileAds

final class AdManager: NSObject {

    static let shared = AdManager()
    private override init() { super.init() }

    // MARK: - Ad IDs
    // Replace with real Ad Unit IDs from AdMob dashboard

    #if DEBUG
    private let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313" // Test ID
    #else
    private let rewardedAdUnitID = "ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY" // Production ID
    #endif

    private var rewardedAd: GADRewardedAd?
    private var rewardCompletion: ((Int?) -> Void)?

    // MARK: - Load

    func loadRewardedAd() {
        guard FeatureFlags.shared.isRewardedAdsEnabled else { return }
        let request = GADRequest()
        GADRewardedAd.load(withAdUnitID: rewardedAdUnitID, request: request) { [weak self] ad, error in
            if let error {
                print("[AdManager] Rewarded ad load error: \(error.localizedDescription)")
                return
            }
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
        }
    }

    // MARK: - Show

    func showRewardedAd(completion: @escaping (Int?) -> Void) {
        guard let ad = rewardedAd else {
            print("[AdManager] No rewarded ad loaded. Loading now...")
            loadRewardedAd()
            completion(nil)
            return
        }

        rewardCompletion = completion

        guard let rootVC = topViewController() else {
            completion(nil)
            return
        }

        ad.present(fromRootViewController: rootVC) { [weak self] in
            let rewardAmount = Int(ad.adReward.amount)
            let coins = rewardAmount * 10 // Scale ad reward to coin amount
            self?.rewardCompletion?(coins)
            self?.rewardCompletion = nil
            // Pre-load next ad
            self?.loadRewardedAd()
        }
    }

    // MARK: - Helpers

    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        return windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
    }
}

// MARK: - GADFullScreenContentDelegate

extension AdManager: GADFullScreenContentDelegate {
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[AdManager] Ad failed to present: \(error.localizedDescription)")
        rewardCompletion?(nil)
        rewardCompletion = nil
        loadRewardedAd()
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        loadRewardedAd()
    }
}
