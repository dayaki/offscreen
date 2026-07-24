# Offscreen

A native macOS menu bar app that protects your eyes with smart screen breaks —
and knows when not to interrupt. Built in Swift/SwiftUI for macOS 15 and later,
inspired by the apps that pioneered mindful screen breaks, but native, private,
and free.

**[Website](https://dayaki.github.io/offscreen/)** · **[Download the latest release](https://github.com/dayaki/offscreen/releases/latest)** · macOS 15+ · Apple silicon · signed & notarized

## Features

- **Break cycles** — short breaks after each work interval (Balanced 20 min/20 s,
  Deep Focus 45 min/30 s, 20-20-20, or fully custom), with a long break every
  Nth cycle.
- **Considerate break flow** — a heads-up panel appears before each break
  (start now, or snooze +1/+5/+15 min with a per-cycle limit) without stealing
  keyboard focus; a countdown pill follows your cursor in the last seconds;
  then a full-screen overlay with a countdown ring and a rotating message
  covers every display, even over fullscreen apps.
- **Skip difficulty** — Casual (skip anytime), Balanced (skip unlocks a few
  seconds in), Hardcore (no skipping). Optional end-early after a minimum, and
  optional auto-lock when a break starts.
- **Smart Pause** — breaks hold automatically while your camera or mic is in
  use (meetings), the screen is shared or recorded, a fullscreen app is
  frontmost, or a designated deep-focus app is active. A due break also waits
  for a typing lull. Idle time and sleep/lock pause the timer, and a long
  absence counts as a break taken. Audio playback isn't used as a pause
  signal — browsers keep audio-output streams open even when nothing's
  playing, so it's unreliable; fullscreen video and calls are already caught
  by the signals above.
- **Scheduling** — Office Hours (only remind during chosen hours/days) and
  Planned Breaks (named breaks at fixed times, e.g. lunch) that reuse the same
  heads-up flow.
- **Break-over sound** — a sound that plays *when a break ends* (not during it)
  to let you know it's over, even from across the room. It keeps playing until
  you touch the keyboard or mouse — i.e. until you're back — then stops itself.
  Ships with four built-in tracks (Rain, Ocean Waves, Brown Noise, Soft Wind);
  pick one in Settings, or add your own file (see below).
- **Stats** — daily Screen Score, active screen time, breaks taken/skipped/
  snoozed, and per-app usage, stored locally in SQLite with a 7-day chart view.
- **System integration** — live menu bar countdown and controls, global
  hotkeys (⌥⇧B break now, ⌥⇧P pause toggle), launch at login, and a
  Settings window (General / Breaks / Smart Pause / Schedule / Appearance).

**Zero permission prompts**: every detector uses permission-free APIs
(CoreMediaIO/CoreAudio HAL properties, CGWindowList bounds, CGEventSource
idle queries) — the app never asks for Accessibility, Screen Recording,
Input Monitoring, camera, or microphone access.

## Install

**Homebrew** (recommended):

```sh
brew install --cask dayaki/tap/offscreen
```

This adds the tap `dayaki/tap` and installs `Offscreen.app` into
`/Applications`. Update later with `brew upgrade --cask offscreen`.

**Or download directly:** grab `Offscreen-<version>.zip` from the
[latest release](https://github.com/dayaki/offscreen/releases/latest), unzip,
and drag `Offscreen.app` to Applications. Releases are Developer ID-signed and
notarized by Apple, so they open without a Gatekeeper warning.

Requires macOS 15 (Sequoia) or later on Apple silicon.

## Build from source

Requires Xcode 26+ (Swift 6.2 toolchain).

```sh
Scripts/build-app.sh          # swift build → Offscreen.app → ~/Applications
open ~/Applications/Offscreen.app
```

`Scripts/dev.sh` rebuilds, kills any running copy, and relaunches.

## Development

```sh
swift test                    # engine, scheduling, office-hours unit tests

# Time-compressed run: N virtual seconds per real second
OFFSCREEN_TIME_SCALE=60 Scripts/dev.sh

# Real-time but compressed cycle (90 s work / 15 s break, 60 s heads-up):
OFFSCREEN_DEBUG_TIMING=1 Scripts/dev.sh
```

Debug commands (also in the menu bar's Debug submenu during debug runs):

```sh
swift -e 'import Foundation; DistributedNotificationCenter.default().postNotificationName(.init("com.dayo.offscreen.debug.breakNow"), object: nil, userInfo: nil, deliverImmediately: true)'
# also: .debug.skip  .debug.snooze  .debug.preBreak  .debug.dueNow  .debug.dump
```

Logs:

```sh
/usr/bin/log stream --predicate 'subsystem == "com.dayo.offscreen"' --level info
```

Data lives in `~/Library/Application Support/Offscreen/` (`settings.json`,
`stats.sqlite`).

### Adding your own break-over sounds

The four built-in tracks are generated with `ffmpeg` (`Resources/Ambient/*.m4a`,
regenerate with `Scripts/make-ambient.sh`) and bundled into the app. To use your
own audio (e.g. a track downloaded from [Pixabay](https://pixabay.com/music/)),
drop `.mp3`/`.wav`/`.aiff`/`.m4a`/`.flac` files into:

```
~/Library/Application Support/Offscreen/Sounds
```

Then open **Settings → Appearance → When a break ends** and click **Rescan** —
your files appear in the picker below the built-in tracks. Or use **Add Your
Own…**, which copies a file into that folder and selects it in one step. The ▶
button previews the selected track. The sound loops until you return to your
desk, so the track doesn't need to be long.

## Cutting a release

Releases are built, Developer ID-signed, notarized, and stapled by
`Scripts/release.sh`, which emits `dist/Offscreen-<version>.zip`.

One-time setup (needs a paid Apple Developer Program membership):

```sh
# 1. Create a "Developer ID Application" cert (Xcode → Settings → Accounts →
#    Manage Certificates → + → Developer ID Application), then confirm:
security find-identity -v -p codesigning | grep "Developer ID Application"

# 2. Store notarization credentials once (uses an app-specific password from
#    appleid.apple.com; the profile name is what release.sh expects):
xcrun notarytool store-credentials "offscreen-notary" \
  --apple-id "<you@example.com>" --team-id "<TEAMID>" --password "<app-specific-password>"
```

Then, per release:

```sh
# bump CFBundleShortVersionString in Resources/Info.plist, then:
Scripts/release.sh                       # → dist/Offscreen-<version>.zip (+ sha256)
gh release create v<version> dist/Offscreen-<version>.zip --title "Offscreen <version>"
# update Casks/offscreen.rb in the homebrew-tap repo with the new version + sha256
```

## Architecture (short version)

- `Core/BreakEngine` — @MainActor state machine (working → preBreak →
  inBreak, with holding/idlePaused/inactive), ticked 4×/s using monotonic
  clock deltas so sleep and clock changes can't corrupt timing.
- `Monitors/*` — permission-free Smart Pause signal sources feeding
  `Core/SmartPauseController`, which gates them by settings into engine holds.
- `Windows/*` — overlay windows (`.screenSaver` level, joins fullscreen
  Spaces), non-activating pre-break panel, cursor pill.
- `Persistence/*` — JSON settings store (lenient decoding) + GRDB stats.
- `App/AppContainer` — composition root wiring everything; no singletons.
