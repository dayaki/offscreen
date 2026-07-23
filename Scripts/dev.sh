#!/bin/bash
# Rebuild and relaunch Offscreen. Pass OFFSCREEN_TIME_SCALE=N to speed up time
# (N virtual seconds per real second) — requires direct launch so env flows through.
set -euo pipefail
cd "$(dirname "$0")/.."

pkill -x Offscreen 2>/dev/null || true
Scripts/build-app.sh

APP="$HOME/Applications/Offscreen.app"
if [ -n "${OFFSCREEN_TIME_SCALE:-}" ] || [ -n "${OFFSCREEN_DIRECT:-}" ]; then
    nohup "$APP/Contents/MacOS/Offscreen" >/dev/null 2>&1 &
    disown
    echo "✓ Launched directly (pid $!, OFFSCREEN_TIME_SCALE=${OFFSCREEN_TIME_SCALE:-1})"
else
    open "$APP"
    echo "✓ Launched via LaunchServices"
fi
