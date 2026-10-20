#!/usr/bin/env bash
# Turn the captures of the nested Shell into the media of the README.
#
#   dev/nested/nested.sh --scenario demo --out DIR    (records DIR/demo-raw.mp4 with the Shell slowed down)
#   WM_PREFS_LANG=fr_FR.UTF-8 dev/nested/nested.sh --scenario prefs --size 1100x900 --out PDIR
#   dev/nested/make-media.sh [--demo DIR] [--poster-at SECONDS] [--prefs PDIR ...]
#
# --demo   writes media/demo.mp4 (real time), media/demo.gif and media/demo-poster.png
# --prefs  writes media/prefs-<lang>.png: the preferences window cut out of PDIR/prefs.png (repeat for each language)
#
# The demo runs with the Shell's slow-down factor (DIR/demo-marks.json) so that a loaded machine still renders every
# frame; the timestamps are divided by the same factor here, which gives back the real speed. Nothing is drawn or
# edited: every frame is a frame of the nested GNOME Shell.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dir=''; poster_at=4.7; prefs=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --demo) dir="${2:?}"; shift 2 ;;
        --poster-at) poster_at="${2:?}"; shift 2 ;;
        --prefs) prefs+=("${2:?}"); shift 2 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done
[[ -n "$dir" || ${#prefs[@]} -gt 0 ]] || { sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2; }
command -v ffmpeg >/dev/null || { echo "ffmpeg is required" >&2; exit 2; }
out="$ROOT/media"
mkdir -p "$out"

for p in "${prefs[@]}"; do
    [[ -f "$p/prefs.png" && -f "$p/prefs.json" ]] || { echo "no preferences capture in $p" >&2; exit 2; }
    # Window frame plus 24 px of its shadow on each side; the language code is the one of the locale (C = en).
    read -r lang crop < <(python3 - "$p/prefs.json" <<'PY'
import json, sys
w = json.load(open(sys.argv[1]))
lang = w["lang"].split("_")[0].split(".")[0].lower()
m = 24
print("en" if lang in ("c", "posix") else lang, f"{w['w'] + 2 * m}:{w['h'] + 2 * m}:{w['x'] - m}:{w['y'] - m}")
PY
)
    ffmpeg -v error -y -i "$p/prefs.png" -vf "crop=$crop" "$out/prefs-$lang.png"
    printf '%s  %s\n' "$(du -h "$out/prefs-$lang.png" | cut -f1)" "media/prefs-$lang.png"
done
[[ -n "$dir" ]] || exit 0
raw="$dir/demo-raw.mp4"
[[ -f "$raw" && -f "$dir/demo-marks.json" ]] || { echo "no demo recording in $dir (run the demo scenario first)" >&2; exit 2; }
slow="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["slowdown"])' "$dir/demo-marks.json")"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT

# Real speed, constant 60 fps, H.264 that every browser and GitHub play.
ffmpeg -v error -y -i "$raw" -vf "setpts=PTS/$slow,fps=60,format=yuv420p" -an \
    -c:v libx264 -preset slow -crf 22 -movflags +faststart "$out/demo.mp4"
# GIF for the README: 800 px wide, 30 fps, one palette for the whole clip (flat colours, so no dithering needed).
ffmpeg -v error -y -i "$out/demo.mp4" -vf "fps=30,scale=800:-1:flags=lanczos,palettegen=max_colors=128:stats_mode=full" \
    "$work/palette.png"
ffmpeg -v error -y -i "$out/demo.mp4" -i "$work/palette.png" \
    -lavfi "fps=30,scale=800:-1:flags=lanczos[v];[v][1:v]paletteuse=dither=none" -loop 0 "$out/demo.gif"
ffmpeg -v error -y -ss "$poster_at" -i "$out/demo.mp4" -frames:v 1 "$out/demo-poster.png"
for f in demo.mp4 demo.gif demo-poster.png; do
    printf '%s  %s\n' "$(du -h "$out/$f" | cut -f1)" "media/$f"
done
