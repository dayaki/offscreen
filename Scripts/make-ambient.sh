#!/bin/bash
# Regenerate the built-in ambient break loops in Resources/Ambient.
# Requires ffmpeg. Each track is a seamless mono loop (integer number of LFO
# periods where a slow amplitude swell is used), so it repeats without a click
# and fills a break of any length.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="Resources/Ambient"
mkdir -p "$OUT"
DUR=300 # seconds; loops seamlessly, so length only affects file size

enc=(-ar 44100 -ac 1 -c:a aac -b:a 96k -y)

echo "Rain…"
ffmpeg -hide_banner -loglevel error -f lavfi -i "anoisesrc=color=pink:amplitude=0.8:duration=$DUR" \
  -af "highpass=f=500,lowpass=f=9000,alimiter=limit=0.9" "${enc[@]}" "$OUT/rain.m4a"

echo "Ocean Waves…"  # 0.1 Hz swell => 10 s waves; 300 s = 30 whole periods
ffmpeg -hide_banner -loglevel error -f lavfi -i "anoisesrc=color=brown:amplitude=0.9:duration=$DUR" \
  -af "lowpass=f=2200,tremolo=f=0.1:d=0.6,alimiter=limit=0.9" "${enc[@]}" "$OUT/ocean.m4a"

echo "Brown Noise…"
ffmpeg -hide_banner -loglevel error -f lavfi -i "anoisesrc=color=brown:amplitude=0.8:duration=$DUR" \
  -af "lowpass=f=1800,alimiter=limit=0.9" "${enc[@]}" "$OUT/brown-noise.m4a"

echo "Soft Wind…"  # 0.15 Hz => 300 s = 45 whole periods
ffmpeg -hide_banner -loglevel error -f lavfi -i "anoisesrc=color=pink:amplitude=0.7:duration=$DUR" \
  -af "highpass=f=180,lowpass=f=1400,tremolo=f=0.15:d=0.5,alimiter=limit=0.9" "${enc[@]}" "$OUT/wind.m4a"

echo "Done → $OUT"
ls -lh "$OUT"
