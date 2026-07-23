#!/bin/bash
# Build, Developer ID-sign, notarize, and staple a distributable Offscreen.app,
# then package it as dist/Offscreen-<version>.zip for a GitHub release / Homebrew.
#
# Prerequisites (one-time, interactive — see README "Cutting a release"):
#   1. A "Developer ID Application" certificate in your login keychain.
#   2. A stored notarytool credential profile:
#        xcrun notarytool store-credentials "offscreen-notary" \
#          --apple-id "<you@example.com>" --team-id "<TEAMID>" --password "<app-specific-password>"
#
# Env overrides: DEVID_IDENTITY, NOTARY_PROFILE, VERSION
set -euo pipefail
cd "$(dirname "$0")/.."

NOTARY_PROFILE="${NOTARY_PROFILE:-offscreen-notary}"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)}"

# Resolve the Developer ID Application identity (full name so codesign is unambiguous).
if [ -z "${DEVID_IDENTITY:-}" ]; then
    DEVID_IDENTITY=$(security find-identity -v -p codesigning \
        | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)"/\1/')
fi
if [ -z "${DEVID_IDENTITY:-}" ]; then
    echo "✗ No 'Developer ID Application' certificate found in the keychain." >&2
    echo "  Create one in Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application." >&2
    exit 1
fi
echo "→ Signing identity: $DEVID_IDENTITY"
echo "→ Version:          $VERSION"

# 1. Release build + bundle assembly (reuses the normal build, signed fresh below).
CONFIG=release CODESIGN_IDENTITY="$DEVID_IDENTITY" Scripts/build-app.sh >/dev/null

APP="build/Offscreen.app"

# 2. Re-sign for distribution: hardened runtime + secure timestamp, inside-out.
#    (build-app.sh already signed with this identity, but without the runtime
#    option; sign again explicitly so notarization requirements are met.)
find "$APP/Contents/Resources" -type d -name "*.bundle" -print0 2>/dev/null \
    | while IFS= read -r -d '' b; do
        codesign --force --options runtime --timestamp --sign "$DEVID_IDENTITY" "$b"
    done
codesign --force --options runtime --timestamp --sign "$DEVID_IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

# 3. Package and submit for notarization.
mkdir -p dist
ZIP="dist/Offscreen-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "→ Submitting to Apple notary service (this can take a few minutes)…"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

# 4. Staple the ticket into the app, then re-zip the stapled app.
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose=4 "$APP" || true
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')
echo ""
echo "✓ $ZIP"
echo "  sha256: $SHA"
echo "  version: $VERSION"
