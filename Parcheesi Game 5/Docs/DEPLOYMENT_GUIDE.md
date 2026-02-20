# Parcheesi Quest — App Store Deployment & TestFlight Guide

---

## Phase 1: Pre-Submission Checklist

### Code & Build
- [ ] All feature flags tested in both enabled/disabled states
- [ ] No hardcoded test values, debug print statements, or `TODO:` comments in release code
- [ ] `#if DEBUG` guards around all emulator/test configurations
- [ ] `AdManager.swift` uses production Ad Unit IDs (not test IDs)
- [ ] `GoogleService-Info.plist` is for production Firebase project (not dev)
- [ ] All IAP Product IDs match App Store Connect exactly
- [ ] APNs configured with production certificate

### App Store Connect
- [ ] App record created at appstoreconnect.apple.com
- [ ] Bundle ID matches Xcode project (`com.yourcompany.ParcheesiGame`)
- [ ] All IAP products created and approved (or submitted for review)
- [ ] App Privacy details filled in
- [ ] Age rating set (typically 4+ for board games)
- [ ] App Store screenshots created for all required device sizes

### Required Screenshots (as of 2024)
| Device | Resolution |
|--------|-----------|
| iPhone 6.7" (Pro Max) | 1290 × 2796 |
| iPhone 6.5" (Plus) | 1242 × 2688 |
| iPad Pro 12.9" 6th gen | 2048 × 2732 |
| iPad Pro 12.9" 2nd gen | 2048 × 2732 |

Use Simulator + `CMD+S` or Sketch/Figma for marketing screenshots.

---

## Phase 2: Archive & Upload

### Step 1: Set Version & Build Number

In Xcode:
- **Version:** `1.0.0` (semantic versioning: major.minor.patch)
- **Build Number:** `1` (increment for every upload)

Or via command line:
```bash
agvtool new-marketing-version 1.0.0
agvtool next-version -all
```

### Step 2: Select Release Scheme

1. Xcode → Product menu → **Scheme** → **Edit Scheme**
2. Set **Run** configuration to **Release**
3. Scheme → Select **Any iOS Device (arm64)** as destination

### Step 3: Archive

```
Product → Archive
```

Wait for build to complete. The Organizer window opens automatically.

### Step 4: Validate Archive

1. In Organizer → Select your archive
2. Click **Validate App**
3. Choose **App Store Connect** distribution
4. Let Xcode upload symbols and check for issues
5. Fix any validation errors before proceeding

### Step 5: Distribute to App Store Connect

1. Organizer → **Distribute App**
2. Choose **App Store Connect**
3. Click **Upload** (not "Export")
4. Wait for upload to complete (~2-10 minutes)

### Step 6: Command-Line Upload (Alternative)

```bash
# Export archive first
xcodebuild -exportArchive \
  -archivePath ParcheesiGame.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist

# Upload with altool (deprecated) or notarytool
xcrun altool --upload-app \
  --type ios \
  --file ./build/ParcheesiGame.ipa \
  --apiKey YOUR_API_KEY \
  --apiIssuer YOUR_ISSUER_ID
```

**ExportOptions.plist:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
```

---

## Phase 3: TestFlight

### Internal Testing (Team members)

1. App Store Connect → **TestFlight** tab
2. Wait for build processing (15-30 minutes, email notification sent)
3. **Internal Testing** → Select your team members
4. They receive an email with TestFlight install link

### External Testing (Beta Testers)

1. **External Groups** → **+** → Create a group (e.g., "Beta Testers")
2. Add build to the group
3. Fill in **What to Test** notes
4. Submit for **Beta App Review** (usually 1-2 business days)
5. After approval, share the **Public Link** or invite testers by email

### TestFlight Best Practices

```
Beta Testing Checklist:
- [ ] Test all 4 game modes (Local, Online, Private Room, vs AI)
- [ ] Test all 3 AI difficulty levels
- [ ] Test IAP on Sandbox accounts (not real purchases in TestFlight)
- [ ] Test push notifications (turn reminders, room invites)
- [ ] Test daily reward flow
- [ ] Test sign out / sign in flow
- [ ] Test reconnect after backgrounding
- [ ] Test on iPhone SE (smallest supported) and iPad
- [ ] Test Dark Mode
- [ ] Test with no internet connection (graceful errors)
```

### Collecting Feedback

- Enable **Automatic Crash Reporting** in TestFlight settings
- Testers can submit screenshots + notes via TestFlight app
- Monitor **Crashes** tab in App Store Connect

---

## Phase 4: App Store Submission

### Complete App Store Listing

**Required fields in App Store Connect:**

```
App Information:
  Name: Parcheesi Quest
  Subtitle: Classic Strategy Reimagined
  Category: Games → Board
  Secondary Category: Games → Multiplayer

Pricing:
  Price: Free

App Privacy:
  Data types collected:
    - Name (User ID, Account)
    - Email Address (Account)
    - User ID (Authentication)
    - Purchase History (In-app purchases)
    - Crash Data (Analytics)
    - Usage Data (Analytics)

  All linked to identity: Yes (for account data)
  Crash/analytics: Not linked to identity

Age Rating:
  Made for Kids: No
  Gambling: No
  Mature/Suggestive Themes: None
  → Result: 4+
```

### App Description Template

```
Parcheesi Quest is a modern take on the beloved classic board game — now with
online multiplayer, intelligent AI opponents, and a rich progression system.

GAME MODES
• Local Play — Pass your device around with 2-4 friends
• Online Multiplayer — Real-time matches with players worldwide
• Private Rooms — Play with friends using a 6-digit invite code
• vs Computer — Challenge Easy, Medium, or Hard AI opponents

FEATURES
🎲 Smooth dice rolling animations
♟ Strategic token movement with capture mechanics
🛡 Safe zones and blockade strategy
⏱ Turn timer for online play
💬 In-game chat with emoji support
🏆 XP, levels, and win streak tracking
👤 Custom avatars and board themes
🎁 Daily login rewards

No pay-to-win: all gameplay is completely fair and skill-based.
Cosmetic purchases are optional.

Requires iOS 17.0 or later.
```

### Submit for Review

1. App Store Connect → **App Store** tab → Select your build
2. Complete all required sections (screenshots, description, keywords, etc.)
3. Answer review questions (encryption: **No** for standard HTTPS)
4. Click **Submit for Review**

**Typical review time:** 24–48 hours (can be faster or slower)

---

## Phase 5: Post-Launch

### Monitor Crash Reports

```bash
# Via Xcode Organizer → Crashes
# Or Firebase Crashlytics dashboard
# Or App Store Connect → Metrics → Crashes
```

### Version Update Workflow

1. Increment **Build Number** for every upload
2. Increment **Version Number** for user-visible changes
3. Archive → Distribute → Submit new build for review
4. Write **What's New** release notes

### Backend Monitoring

- **Firebase Console** → Monitor Firestore reads/writes (watch quotas)
- **Cloud Functions** → Monitor invocations and errors
- **Realtime Database** → Monitor concurrent connections
- **Remote Config** → Push feature flag changes without app update

### Scaling Considerations

For >10k DAU:
- Enable **Firestore offline caching** on client
- Implement **pagination** on leaderboard queries
- Add **Cloud Armor / rate limiting** to callable functions
- Consider moving matchmaking to a dedicated server (e.g., Nakama)

---

## CI/CD with GitHub Actions (Optional)

Create `.github/workflows/deploy.yml`:

```yaml
name: Build and Deploy

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Set up Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '15.0'

      - name: Install dependencies
        run: xcodebuild -resolvePackageDependencies

      - name: Build for testing
        run: |
          xcodebuild test \
            -scheme ParcheesiGame \
            -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
            -resultBundlePath TestResults.xcresult

      - name: Archive
        if: github.ref == 'refs/heads/main'
        run: |
          xcodebuild archive \
            -scheme ParcheesiGame \
            -archivePath ParcheesiGame.xcarchive \
            -configuration Release

      - name: Upload to TestFlight
        if: github.ref == 'refs/heads/main'
        run: |
          xcrun altool --upload-app \
            --type ios \
            --file ./ParcheesiGame.ipa \
            --apiKey ${{ secrets.APP_STORE_API_KEY }} \
            --apiIssuer ${{ secrets.APP_STORE_ISSUER_ID }}
```

Store these secrets in GitHub repository settings:
- `APP_STORE_API_KEY` — Your App Store Connect API key content
- `APP_STORE_ISSUER_ID` — Your Issuer ID
- `TEAM_ID` — Your Apple Team ID

---

## Common Rejection Reasons & Fixes

| Rejection | Fix |
|-----------|-----|
| 2.1 App Completeness | Ensure all features work in review environment |
| 3.1.1 IAP required | Make sure purchases work with Sandbox accounts |
| 4.3 Spam | Ensure app has unique value, original assets |
| 5.1.1 Data Privacy | Complete all App Privacy disclosures |
| Sign in with Apple | Must be offered if using other social sign-in |

---

## Helpful Links

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Firebase iOS Docs](https://firebase.google.com/docs/ios/setup)
- [StoreKit 2 Documentation](https://developer.apple.com/documentation/storekit)
- [TestFlight Documentation](https://developer.apple.com/testflight/)
