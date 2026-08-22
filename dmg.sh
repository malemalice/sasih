#!/bin/bash
# Packages Sasih.app into a distributable DMG for direct (non-App-Store)
# distribution. Run ./build.sh (optionally --sign) first. See PRD.md §6/§8
# and PRODUCT_PLAN.md §4 for why this is direct DMG distribution, not the
# App Store.
#
# This script does NOT notarize the DMG — notarization needs an Apple ID
# with an app-specific password / API key and hits Apple's servers, so it's
# a deliberate manual step:
#   xcrun notarytool submit Sasih.dmg --keychain-profile <profile> --wait
#   xcrun stapler staple Sasih.dmg
set -euo pipefail

APP_NAME="Sasih"
BUNDLE="${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
STAGING_DIR=".dmg-staging"

if [ ! -d "$BUNDLE" ]; then
    echo "error: $BUNDLE not found — run ./build.sh first (add --sign for a signed build)." >&2
    exit 1
fi

rm -rf "$STAGING_DIR" "$DMG_NAME"
mkdir -p "$STAGING_DIR"
cp -R "$BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_NAME"

rm -rf "$STAGING_DIR"

echo "Done: $DMG_NAME"
echo "Notarize before distributing: see the comment at the top of this script."
