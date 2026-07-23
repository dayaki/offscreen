#!/bin/bash
# Generates the Offscreen "eye-closed" mark:
#   Resources/AppIcon.icns   — dock / Finder app icon (white glyph on a dark squircle)
#   Resources/MenuBarIcon.png — menu bar template image (black glyph on transparent)
#
# The glyph is Phosphor's `eye-closed` (fill), the same mark used on the website.
# Rendering needs Google Chrome (for a crisp webfont glyph); assembly uses the
# macOS sips/iconutil tools. Run once when the mark changes: Scripts/make-icon.sh
set -euo pipefail
cd "$(dirname "$0")/.."

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || CHROME="/Applications/Chromium.app/Contents/MacOS/Chromium"
[ -x "$CHROME" ] || { echo "✗ Google Chrome or Chromium is required to render the glyph"; exit 1; }

CSS="https://cdn.jsdelivr.net/npm/@phosphor-icons/web@2.1.2/src/fill/style.css"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

shot() { # <html-path> <out-png> <size>
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --default-background-color=00000000 --virtual-time-budget=4000 \
    --window-size="$3,$3" --screenshot="$2" "file://$1" >/dev/null 2>&1
}

# App icon — white eye-closed on a dark squircle (1024).
cat > "$TMP/app.html" <<HTML
<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="$CSS">
<style>html,body{margin:0;width:1024px;height:1024px;background:transparent}
.sq{position:absolute;inset:52px;border-radius:210px;
 background:linear-gradient(160deg,#2b2b30 0%,#0a0a0c 60%,#000 100%);
 display:flex;align-items:center;justify-content:center;
 box-shadow:inset 0 3px 0 rgba(255,255,255,.07),inset 0 -6px 24px rgba(0,0,0,.6)}
.sq i{font-size:500px;color:#fff;line-height:1}</style></head>
<body><div class="sq"><i class="ph-fill ph-eye-closed"></i></div></body></html>
HTML
shot "$TMP/app.html" "$TMP/appicon.png" 1024

# Menu bar — dark eye-closed glyph inside a white circle badge, on transparent.
# This is a FULL-COLOR image (not a template), so it must be loaded with
# isTemplate = false; the white badge makes it pop on a dark menu bar.
cat > "$TMP/menu.html" <<HTML
<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="$CSS">
<style>html,body{margin:0;width:256px;height:256px;background:transparent;
 display:flex;align-items:center;justify-content:center}
.badge{width:248px;height:248px;border-radius:50%;background:#fff;
 display:flex;align-items:center;justify-content:center}
.badge i{font-size:150px;color:#0a0a0c;line-height:1}</style></head>
<body><div class="badge"><i class="ph-fill ph-eye-closed"></i></div></body></html>
HTML
shot "$TMP/menu.html" "$TMP/menubar.png" 256
sips -z 36 36 "$TMP/menubar.png" --out Resources/MenuBarIcon.png >/dev/null

# Assemble the .icns from the 1024 master.
ICONSET="$TMP/AppIcon.iconset"; mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z "$s" "$s" "$TMP/appicon.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2)); sips -z "$d" "$d" "$TMP/appicon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns

# Website favicon / nav logo mirrors the app icon (256).
sips -z 256 256 "$TMP/appicon.png" --out docs/icon.png >/dev/null

echo "✓ Resources/AppIcon.icns"
echo "✓ Resources/MenuBarIcon.png"
echo "✓ docs/icon.png"
