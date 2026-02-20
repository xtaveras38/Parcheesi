// StoreView.swift
// In-app purchase store with coins, gems, themes, and premium

import SwiftUI
import StoreKit

struct StoreView: View {

    @StateObject private var storeVM = StoreViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            Group {
                if storeVM.isLoading && storeVM.products.isEmpty {
                    ProgressView("Loading store...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    storeContent
                }
            }
            .navigationTitle("Store")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Restore") {
                        Task { await storeVM.restorePurchases() }
                    }
                    .font(.subheadline)
                }
            }
            .alert("Purchase Failed", isPresented: .constant(storeVM.purchaseError != nil)) {
                Button("OK") { storeVM.purchaseError = nil }
            } message: {
                Text(storeVM.purchaseError ?? "")
            }
            .alert("Success!", isPresented: .constant(storeVM.purchaseSuccess != nil)) {
                Button("OK") { storeVM.purchaseSuccess = nil }
            } message: {
                Text(storeVM.purchaseSuccess ?? "")
            }
        }
    }

    // MARK: - Store Content

    private var storeContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Daily deal banner
                dailyDealBanner

                // Rewarded ad button
                if FeatureFlags.shared.isRewardedAdsEnabled {
                    rewardedAdButton
                }

                // Premium section
                premiumSection

                // Coin packs
                storeSection(title: "🪙 Coin Packs", icon: "coin", items: coinProducts)

                // Gem packs
                storeSection(title: "💎 Gem Packs", icon: "gem", items: gemProducts)

                // Themes
                themesSection

                Spacer(minLength: 40)
            }
            .padding()
        }
    }

    // MARK: - Sections

    private var dailyDealBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Daily Deal", systemImage: "tag.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("⏱ 12:34:56")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
            Text("Double coins on all packs today only!")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.orange, Color.red],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var rewardedAdButton: some View {
        Button {
            storeVM.showRewardedAd { coins in }
        } label: {
            HStack {
                Image(systemName: "play.rectangle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                VStack(alignment: .leading) {
                    Text("Watch Ad")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Earn 50 free coins!")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.indigo)
            )
        }
        .buttonStyle(.plain)
    }

    private var premiumSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("👑 Premium Membership")
                .font(.title3.bold())

            VStack(spacing: 8) {
                Label("No ads ever", systemImage: "xmark.octagon.fill")
                Label("Daily gem bonus (+10/day)", systemImage: "sparkles")
                Label("Exclusive avatars & themes", systemImage: "crown.fill")
                Label("Priority matchmaking", systemImage: "bolt.fill")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                ForEach(premiumProducts, id: \.id) { product in
                    Button {
                        Task { await storeVM.purchase(product) }
                    } label: {
                        VStack(spacing: 4) {
                            Text(product.displayName)
                                .font(.caption.bold())
                            Text(product.displayPrice)
                                .font(.headline)
                                .foregroundStyle(Color.accentColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentColor.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.accentColor, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [Color.yellow.opacity(0.15), Color.orange.opacity(0.1)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
    }

    private func storeSection(title: String, icon: String, items: [Product]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(items, id: \.id) { product in
                    ProductCard(product: product) {
                        Task { await storeVM.purchase(product) }
                    }
                }
            }
        }
    }

    private var themesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🎨 Board Themes")
                .font(.title3.bold())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(BoardTheme.all) { theme in
                        ThemeCard(theme: theme)
                    }
                }
            }
        }
    }

    // MARK: - Product Helpers

    private var coinProducts: [Product] {
        storeVM.products.filter { $0.id.contains("coins") }
    }
    private var gemProducts: [Product] {
        storeVM.products.filter { $0.id.contains("gems") }
    }
    private var premiumProducts: [Product] {
        storeVM.products.filter { $0.id.contains("premium") }
    }
}

// MARK: - Product Card

struct ProductCard: View {
    let product: Product
    let onPurchase: () -> Void

    var body: some View {
        Button(action: onPurchase) {
            VStack(spacing: 8) {
                // Icon
                Text(productIcon)
                    .font(.system(size: 32))

                Text(product.displayName)
                    .font(.caption.bold())
                    .multilineTextAlignment(.center)

                if let bonus = bonusLabel {
                    Text(bonus)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                }

                Text(product.displayPrice)
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }

    private var productIcon: String {
        if product.id.contains("coins") { return "🪙" }
        if product.id.contains("gems") { return "💎" }
        return "⭐"
    }

    private var bonusLabel: String? {
        if product.id.contains("500") { return "+10% Bonus" }
        if product.id.contains("2000") { return "+20% Bonus" }
        if product.id.contains("200") { return "+15% Bonus" }
        return nil
    }
}

// MARK: - Theme Card

struct ThemeCard: View {
    let theme: BoardTheme

    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: themeColors,
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 70)
                .overlay(
                    Text("🎲")
                        .font(.title)
                )

            Text(theme.name)
                .font(.caption.bold())

            if theme.coinPrice > 0 {
                Label("\(theme.coinPrice)", systemImage: "coin")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if theme.isPremiumOnly {
                Text("Premium")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            } else {
                Text("Free")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
    }

    private var themeColors: [Color] {
        switch theme.id {
        case "midnight": return [.black, Color(white: 0.2)]
        case "jungle":   return [.green, Color(red: 0.1, green: 0.5, blue: 0.1)]
        case "ocean":    return [.blue, .cyan]
        case "neon":     return [.purple, .pink]
        case "golden":   return [.yellow, .orange]
        default:         return [Color(red: 0.9, green: 0.8, blue: 0.7), Color(red: 0.7, green: 0.6, blue: 0.5)]
        }
    }
}
