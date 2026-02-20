#!/usr/bin/env bash
# bootstrap.sh — One-command project setup for new developers
# Run from the ParcheesiGame root directory.
set -euo pipefail

echo "=== Parcheesi Quest Bootstrap ==="

# 1. Check Xcode CLI tools
if ! xcode-select -p &>/dev/null; then
  echo "Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "Please re-run bootstrap.sh after installation completes."
  exit 1
fi

# 2. Check Node.js (for Firebase Functions)
if ! command -v node &>/dev/null; then
  echo "ERROR: Node.js is not installed. Install from https://nodejs.org (v18+)"
  exit 1
fi
NODE_VERSION=$(node -v | cut -d. -f1 | tr -d 'v')
if [ "$NODE_VERSION" -lt 18 ]; then
  echo "ERROR: Node.js 18+ required. Found: $(node -v)"
  exit 1
fi

# 3. Install Firebase CLI globally if not present
if ! command -v firebase &>/dev/null; then
  echo "Installing Firebase CLI..."
  npm install -g firebase-tools
fi

# 4. Install Cloud Function dependencies
echo "Installing Cloud Function dependencies..."
cd Firebase/functions && npm install && npm run build
cd ../..

# 5. Check for GoogleService-Info.plist
if [ ! -f "Sources/Resources/GoogleService-Info.plist" ]; then
  echo ""
  echo "⚠️  WARNING: GoogleService-Info.plist not found!"
  echo "   Download it from Firebase Console → Project Settings → iOS app"
  echo "   and place it at: Sources/Resources/GoogleService-Info.plist"
  echo ""
fi

# 6. Open project in Xcode
echo ""
echo "=== Setup complete! ==="
echo ""
echo "Next steps:"
echo "  1. Add GoogleService-Info.plist to Sources/Resources/ (if not done)"
echo "  2. Open ParcheesiGame.xcodeproj in Xcode"
echo "  3. Update DEVELOPMENT_TEAM in project settings"
echo "  4. Update bundle identifier (com.yourcompany.ParcheesiGame)"
echo "  5. Run on device or simulator"
echo ""

if command -v open &>/dev/null; then
  read -rp "Open Xcode now? [y/N] " answer
  if [[ "${answer,,}" == "y" ]]; then
    open ParcheesiGame.xcodeproj
  fi
fi
