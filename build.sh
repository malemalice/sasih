#!/bin/bash
# Assembles Sasih.app from the SPM build output. Needed because this
# machine has no Xcode.app (only Command Line Tools) — `swift build` alone
# produces a bare executable, not something Launch Services, LSUIElement,
# or SMAppService will treat as a real app. See TRD.md §4.
set -euo pipefail

APP_NAME="Sasih"
BUNDLE="${APP_NAME}.app"
CONFIG="release"
SIGN=false

for arg in "$@"; do
    case "$arg" in
        --sign) SIGN=true ;;
        --debug) CONFIG="debug" ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done

echo "Building SasihApp ($CONFIG)..."
swift build -c "$CONFIG" --product SasihApp

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

cp ".build/$CONFIG/SasihApp" "$BUNDLE/Contents/MacOS/$APP_NAME"
cp "Sources/SasihApp/Resources/Info.plist" "$BUNDLE/Contents/Info.plist"

echo "APPL????" > "$BUNDLE/Contents/PkgInfo"

if [ "$SIGN" = true ]; then
    IDENTITY="${SASIH_SIGNING_IDENTITY:-}"
    if [ -z "$IDENTITY" ]; then
        echo "error: --sign requires SASIH_SIGNING_IDENTITY to be set to your Developer ID Application identity." >&2
        exit 1
    fi
    echo "Signing with identity: $IDENTITY"
    codesign --force --deep --options runtime --sign "$IDENTITY" "$BUNDLE"
else
    echo "Built unsigned bundle (use --sign for a Developer ID signed build once a certificate is available)."
fi

echo "Done: $BUNDLE"
echo "Launch with: open $BUNDLE"
