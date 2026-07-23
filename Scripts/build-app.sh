#!/bin/bash
# Build Offscreen.app from the SwiftPM executable and install it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-debug}"
IDENTITY="${CODESIGN_IDENTITY:-Apple Development: Dayo Akinkuowo (H894Y456P9)}"

swift build -c "$CONFIG"

BIN=".build/$CONFIG/Offscreen"
APP="build/Offscreen.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Offscreen"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# SPM resource bundle (present once the target declares resources)
if [ -d ".build/$CONFIG/Offscreen_Offscreen.bundle" ]; then
    cp -R ".build/$CONFIG/Offscreen_Offscreen.bundle" "$APP/Contents/Resources/"
fi
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi
# Menu bar template image (the eye-closed mark).
if [ -f "Resources/MenuBarIcon.png" ]; then
    cp Resources/MenuBarIcon.png "$APP/Contents/Resources/MenuBarIcon.png"
fi

# Bundled ambient tracks (played during breaks).
if [ -d "Resources/Ambient" ]; then
    mkdir -p "$APP/Contents/Resources/Ambient"
    cp Resources/Ambient/*.m4a "$APP/Contents/Resources/Ambient/" 2>/dev/null || true
fi

# SwiftUI shader library (swift build doesn't process .metal files). If the
# Metal toolchain is missing, skip — the app falls back to a SwiftUI-only
# animation when no metallib is present in the bundle.
if [ -f "Resources/Aurora.metal" ]; then
    if xcrun -sdk macosx metal Resources/Aurora.metal \
        -o "$APP/Contents/Resources/default.metallib" 2>/dev/null; then
        echo "✓ Compiled shader library"
    else
        echo "⚠ Metal toolchain unavailable — using SwiftUI fallback animation"
    fi
fi

# Prefer the stable dev cert (keeps TCC/SMAppService identity across rebuilds);
# fall back to ad-hoc if unavailable.
codesign --force --sign "$IDENTITY" "$APP" 2>/dev/null \
    || codesign --force --sign - "$APP"

mkdir -p "$HOME/Applications"
rsync -a --delete "$APP/" "$HOME/Applications/Offscreen.app/"
echo "✓ Installed $HOME/Applications/Offscreen.app ($CONFIG)"
