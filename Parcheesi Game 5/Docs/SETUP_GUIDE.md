# Parcheesi Quest — Complete Setup Guide

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Xcode | 15.0+ | macOS Sonoma recommended |
| iOS Deployment Target | 17.0+ | For latest SwiftUI APIs |
| Node.js | 18+ | For Firebase Functions |
| Firebase CLI | Latest | `npm install -g firebase-tools` |
| CocoaPods (optional) | 1.14+ | Only if not using SPM |

---

## 1. Create the Xcode Project

1. Open Xcode → **New Project**
2. Select **App** under iOS
3. Configure:
   - **Product Name:** `ParcheesiGame`
   - **Team:** Your Apple Developer Team
   - **Bundle ID:** `com.yourcompany.ParcheesiGame`
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Include Tests:** ✅

4. Copy all files from `Sources/` into the Xcode project (maintaining the folder hierarchy)

---

## 2. Firebase Setup

### 2a. Create Firebase Project

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Click **Add Project** → Name it `ParcheesiGame`
3. Enable **Google Analytics** (recommended)
4. After creation, click **Add app** → **iOS**
5. Enter your **Bundle ID** (e.g., `com.yourcompany.ParcheesiGame`)
6. Download `GoogleService-Info.plist`
7. Drag `GoogleService-Info.plist` into Xcode (root of project, check "Add to target")

### 2b. Enable Firebase Services

In Firebase Console, enable:

- **Authentication** → Sign-in methods:
  - Email/Password ✅
  - Apple ✅ (requires Apple Developer account configuration)
- **Firestore Database** → Start in **production mode**
- **Realtime Database** → Start in **locked mode**
- **Storage** → Default bucket
- **Cloud Messaging** → Already enabled
- **Remote Config** → Already enabled
- **Analytics** → Already enabled

### 2c. Configure Apple Sign In (Required for App Store)

1. Apple Developer Portal → **Certificates, IDs & Profiles** → **Identifiers**
2. Select your App ID → Enable **Sign In with Apple**
3. In Firebase Console → Authentication → Apple → enter your Service ID
4. Add the Firebase OAuth redirect URL to your Apple app configuration

---

## 3. Add Firebase SDK via Swift Package Manager

1. In Xcode → **File** → **Add Package Dependencies**
2. Enter: `https://github.com/firebase/firebase-ios-sdk`
3. Select version: **10.0.0** or later (select "Up to Next Major")
4. Add these products to your target:
   - `FirebaseAuth`
   - `FirebaseFirestore`
   - `FirebaseDatabase`
   - `FirebaseStorage`
   - `FirebaseMessaging`
   - `FirebaseRemoteConfig`
   - `FirebaseAnalytics`

### 3b. Add Google Mobile Ads (AdMob)

1. Add package: `https://github.com/googleads/swift-package-manager-google-mobile-ads`
2. Select `GoogleMobileAds` product
3. Create AdMob account at [admob.google.com](https://admob.google.com)
4. Create a new app → Get your **App ID**
5. Add to `Info.plist`:
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY</string>
```

---

## 4. Configure Info.plist

Add these keys to `Info.plist`:

```xml
<!-- Firebase / AdMob -->
<key>GADApplicationIdentifier</key>
<string>YOUR_ADMOB_APP_ID</string>

<!-- Push Notifications -->
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>

<!-- Camera / Photo Library (avatar upload) -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Choose your profile avatar photo</string>
<key>NSCameraUsageDescription</key>
<string>Take a photo for your avatar</string>

<!-- Network -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

---

## 5. Xcode Capabilities

Enable these capabilities in your target's **Signing & Capabilities**:

| Capability | Notes |
|-----------|-------|
| Push Notifications | Required for multiplayer |
| Sign In with Apple | Required for App Store |
| In-App Purchase | Required for monetization |
| Background Modes | `fetch`, `remote-notification` |
| GameKit (optional) | For Game Center leaderboards |

---

## 6. Firebase Cloud Functions Setup

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Navigate to Firebase directory
cd ParcheesiGame/Firebase

# Initialize (select your project)
firebase use --add  # Select your Firebase project

# Install Function dependencies
cd functions && npm install

# Build TypeScript
npm run build

# Deploy to Firebase
npm run deploy
```

---

## 7. Firestore Indexes

Create `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "xp", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "friend_requests",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "receiverID", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" }
      ]
    }
  ]
}
```

Deploy indexes:
```bash
firebase deploy --only firestore:indexes
```

---

## 8. Remote Config Defaults

Deploy the Remote Config template:
```bash
firebase deploy --only remoteconfig
```

---

## 9. App Store Connect — IAP Setup

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Select your app → **In-App Purchases** → **+**
3. Create the following products:

| Product ID | Type | Price |
|-----------|------|-------|
| `com.parcheesigame.coins.100` | Consumable | $0.99 |
| `com.parcheesigame.coins.500` | Consumable | $3.99 |
| `com.parcheesigame.coins.2000` | Consumable | $9.99 |
| `com.parcheesigame.gems.50` | Consumable | $2.99 |
| `com.parcheesigame.gems.200` | Consumable | $9.99 |
| `com.parcheesigame.premium.monthly` | Auto-Renewable | $4.99/mo |
| `com.parcheesigame.premium.yearly` | Auto-Renewable | $29.99/yr |

---

## 10. APNs Configuration

1. Apple Developer Portal → **Keys** → **+** → Create a new key
2. Enable **Apple Push Notifications service (APNs)**
3. Download the `.p8` key file
4. In Firebase Console → **Project Settings** → **Cloud Messaging**
5. Upload the `.p8` file with your **Key ID** and **Team ID**

---

## 11. Local Development with Emulators

```bash
cd ParcheesiGame/Firebase
firebase emulators:start
```

Emulator UI: [http://localhost:4000](http://localhost:4000)

To connect your iOS app to emulators, add to `AppDelegate.swift` (debug only):
```swift
#if DEBUG
Database.database().useEmulator(withHost: "localhost", port: 9000)
Auth.auth().useEmulator(withHost: "localhost", port: 9099)
let settings = FirestoreSettings()
settings.host = "localhost:8080"
settings.cacheSettings = MemoryCacheSettings()
settings.isSSLEnabled = false
Firestore.firestore().settings = settings
#endif
```

---

## 12. Sound Assets

Add the following audio files to your Xcode asset bundle:

| Filename | Format | Description |
|---------|--------|-------------|
| `dice_roll.mp3` | MP3/WAV | Dice rolling sound |
| `token_move.mp3` | MP3/WAV | Token sliding |
| `capture.mp3` | MP3/WAV | Capture sound effect |
| `token_finish.mp3` | MP3/WAV | Token reaching home |
| `victory.mp3` | MP3/WAV | Win fanfare |
| `button_tap.mp3` | MP3/WAV | UI button tap |
| `background_music.mp3` | MP3 | Looping background track |

All sounds must be original or from royalty-free libraries (e.g., freesound.org, Pixabay).

---

## 13. Art Assets Checklist

Add to `Assets.xcassets`:

- App icon (1024×1024 PNG, no transparency)
- Avatar images: `avatar_wanderer`, `avatar_knight`, `avatar_wizard`, `avatar_dragon`, `avatar_phoenix`, `avatar_celestial`
- Theme preview images: `theme_classic`, `theme_midnight`, `theme_jungle`, `theme_ocean`, `theme_neon`, `theme_golden`
- `NavBarBackground` color set
- `PrimaryText` color set
- Accent color

---

## Project File Structure

```
ParcheesiGame/
├── Sources/
│   ├── App/
│   │   ├── AppDelegate.swift          ← Firebase init, push notifs, lifecycle
│   │   ├── ParcheesiGameApp.swift     ← SwiftUI @main entry point
│   │   └── FeatureFlags.swift         ← Remote Config feature toggles
│   ├── Models/
│   │   ├── GameModels.swift           ← Token, Player, GameState, DiceResult
│   │   └── UserProfile.swift          ← UserProfile, XPSystem, Avatar, Theme
│   ├── ViewModels/
│   │   ├── GameViewModel.swift        ← In-game orchestrator
│   │   ├── AuthViewModel.swift        ← Auth state machine
│   │   ├── LobbyViewModel.swift       ← Room management, matchmaking
│   │   ├── ProfileViewModel.swift     ← Profile, friends, stats
│   │   └── StoreViewModel.swift       ← IAP, rewarded ads
│   ├── Views/
│   │   ├── Board/
│   │   │   ├── BoardView.swift        ← SwiftUI board container + HUD
│   │   │   └── BoardScene.swift       ← SpriteKit scene
│   │   ├── Game/
│   │   │   ├── GameScreenView.swift   ← Game screen + win screen
│   │   │   └── ChatView.swift         ← In-game chat
│   │   ├── Menu/
│   │   │   ├── MainMenuView.swift     ← Home screen
│   │   │   ├── AuthView.swift         ← Sign in/up + Apple Sign In
│   │   │   └── RootView.swift         ← Router + splash + daily reward
│   │   ├── Profile/
│   │   │   └── ProfileView.swift      ← Profile, stats, friends, avatars
│   │   ├── Lobby/
│   │   │   └── LobbyView.swift        ← Online lobby + rooms
│   │   └── Store/
│   │       └── StoreView.swift        ← IAP store
│   ├── Engine/
│   │   ├── Rules/
│   │   │   └── GameRules.swift        ← Pure rule engine (stateless)
│   │   ├── State/
│   │   │   └── GameStateManager.swift ← Save/load/reconnect
│   │   └── AI/
│   │       └── AIPlayer.swift         ← 3-level AI + orchestrator
│   ├── Services/
│   │   ├── Firebase/
│   │   │   ├── FirebaseService.swift  ← DB refs + Firestore helpers
│   │   │   ├── UserProfileService.swift ← User CRUD
│   │   │   └── StorageService.swift   ← Avatar image upload
│   │   ├── Networking/
│   │   │   └── MultiplayerNetworkService.swift ← RTDB multiplayer sync
│   │   ├── Audio/
│   │   │   └── AudioService.swift     ← SFX + music
│   │   ├── Haptics/
│   │   │   └── HapticService.swift    ← Haptic patterns
│   │   └── Analytics/
│   │       └── AnalyticsService.swift ← Event tracking
│   └── Utils/
│       ├── AppStateManager.swift
│       ├── ThemeManager.swift
│       ├── AuthService.swift
│       ├── DailyRewardManager.swift
│       ├── UserStatsService.swift
│       ├── NotificationService.swift
│       └── AdManager.swift
├── Tests/
│   └── GameRulesTests.swift           ← Unit tests for rule engine
├── Firebase/
│   ├── functions/src/index.ts         ← Cloud Functions (TypeScript)
│   ├── firestore.rules                ← Firestore security rules
│   ├── database.rules.json            ← RTDB security rules
│   ├── storage.rules                  ← Storage security rules
│   ├── firebase.json                  ← Firebase project config
│   └── remoteconfig.template.json    ← Remote Config defaults
├── Docs/
│   ├── SETUP_GUIDE.md                 ← This file
│   └── DEPLOYMENT_GUIDE.md            ← App Store deployment
└── Package.swift                      ← SPM dependencies reference
```
