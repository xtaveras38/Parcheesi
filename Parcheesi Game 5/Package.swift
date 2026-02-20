// swift-tools-version: 5.9
// Package.swift — Swift Package Manager manifest for ParcheesiGame
// Note: Most iOS apps use an .xcodeproj. This Package.swift is provided
// as a reference for dependency management and SPM-based library structure.

import PackageDescription

let package = Package(
    name: "ParcheesiGame",
    platforms: [
        .iOS(.v17)  // Requires iOS 17+ for latest SwiftUI APIs
    ],
    products: [
        .library(name: "ParcheesiGame", targets: ["ParcheesiGame"]),
    ],
    dependencies: [
        // Firebase iOS SDK — add to Xcode via SPM:
        // https://github.com/firebase/firebase-ios-sdk
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            from: "10.0.0"
        ),
        // Google Mobile Ads (AdMob)
        // https://github.com/googleads/swift-package-manager-google-mobile-ads
        .package(
            url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
            from: "10.0.0"
        ),
    ],
    targets: [
        .target(
            name: "ParcheesiGame",
            dependencies: [
                .product(name: "FirebaseAuth",          package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore",     package: "firebase-ios-sdk"),
                .product(name: "FirebaseDatabase",      package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage",       package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging",     package: "firebase-ios-sdk"),
                .product(name: "FirebaseRemoteConfig",  package: "firebase-ios-sdk"),
                .product(name: "FirebaseAnalytics",     package: "firebase-ios-sdk"),
                .product(name: "GoogleMobileAds",       package: "swift-package-manager-google-mobile-ads"),
            ],
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "ParcheesiGameTests",
            dependencies: ["ParcheesiGame"],
            path: "Tests"
        ),
    ]
)
