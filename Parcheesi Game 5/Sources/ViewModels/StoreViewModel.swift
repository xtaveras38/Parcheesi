// StoreViewModel.swift
// Manages IAP products, purchases, and reward ad display

import Foundation
import StoreKit
import Combine

@MainActor
final class StoreViewModel: ObservableObject {

    // MARK: - Product IDs (must match App Store Connect)

    enum ProductID: String, CaseIterable {
        case coins100     = "com.parcheesigame.coins.100"
        case coins500     = "com.parcheesigame.coins.500"
        case coins2000    = "com.parcheesigame.coins.2000"
        case gems50       = "com.parcheesigame.gems.50"
        case gems200      = "com.parcheesigame.gems.200"
        case premiumMonth = "com.parcheesigame.premium.monthly"
        case premiumYear  = "com.parcheesigame.premium.yearly"
    }

    // MARK: - Published

    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var purchaseError: String?
    @Published var purchaseSuccess: String?
    @Published var userProfile: UserProfile?

    // MARK: - Private

    private let userService = UserProfileService.shared
    private var updateListenerTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        updateListenerTask = listenForTransactions()
        Task { await loadProducts() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        do {
            let ids = ProductID.allCases.map { $0.rawValue }
            products = try await Product.products(for: ids)
            products.sort { $0.price < $1.price }
        } catch {
            purchaseError = "Failed to load products: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        guard FeatureFlags.shared.isIAPEnabled else { return }
        isLoading = true
        purchaseError = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseError = "Transaction could not be verified."
                    isLoading = false
                    return
                }
                await grantPurchase(for: transaction)
                await transaction.finish()
                purchaseSuccess = "Purchase successful!"
                AnalyticsService.shared.track(event: "iap_purchase", properties: [
                    "product_id": product.id,
                    "price": product.price
                ])

            case .userCancelled:
                break

            case .pending:
                purchaseError = "Purchase is pending approval."

            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        isLoading = true
        do {
            try await AppStore.sync()
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    await grantPurchase(for: transaction)
                }
            }
            purchaseSuccess = "Purchases restored!"
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Grant Rewards

    private func grantPurchase(for transaction: Transaction) async {
        guard let uid = AuthService.shared.currentUserID else { return }
        switch transaction.productID {
        case ProductID.coins100.rawValue:
            try? await userService.addCoins(uid: uid, amount: 100)
        case ProductID.coins500.rawValue:
            try? await userService.addCoins(uid: uid, amount: 550) // 10% bonus
        case ProductID.coins2000.rawValue:
            try? await userService.addCoins(uid: uid, amount: 2400) // 20% bonus
        case ProductID.gems50.rawValue:
            try? await userService.addGems(uid: uid, amount: 50)
        case ProductID.gems200.rawValue:
            try? await userService.addGems(uid: uid, amount: 230) // Bonus
        case ProductID.premiumMonth.rawValue, ProductID.premiumYear.rawValue:
            let expiry = transaction.productID == ProductID.premiumMonth.rawValue
                ? Calendar.current.date(byAdding: .month, value: 1, to: Date())!
                : Calendar.current.date(byAdding: .year, value: 1, to: Date())!
            try? await userService.setPremium(uid: uid, expiresAt: expiry)
        default:
            break
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self.grantPurchase(for: transaction)
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Rewarded Ads

    func showRewardedAd(completion: @escaping (Int) -> Void) {
        guard FeatureFlags.shared.isRewardedAdsEnabled else { return }
        AdManager.shared.showRewardedAd { coinReward in
            guard let coinReward, let uid = AuthService.shared.currentUserID else { return }
            Task {
                try? await UserProfileService.shared.addCoins(uid: uid, amount: coinReward)
            }
            AnalyticsService.shared.track(event: "rewarded_ad_completed", properties: ["coins": coinReward])
            completion(coinReward)
        }
    }
}
