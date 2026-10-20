#!/usr/bin/env bash
# Build the zip for extensions.gnome.org (and for the release page) with `gnome-extensions pack`.
#
#   scripts/pack.sh [--out DIR]      default DIR: dist/
#
# Writes DIR/window-magnet@maximeallanic.github.io.shell-extension.zip: the extension's JavaScript, metadata.json,
# the GSettings schema (XML only: GNOME Shell 44 and later compile it at install time) and the compiled
# translations (locale/<lang>/LC_MESSAGES/window-magnet.mo). Then scripts/check-zip.py checks it.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/extension"
UUID=window-magnet@maximeallanic.github.io
out="$ROOT/dist"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --out) out="${2:?--out needs a directory}"; shift ;;
        -h|--help) sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done
command -v gnome-extensions >/dev/null || { echo "gnome-extensions is required (package gnome-shell)" >&2; exit 2; }
command -v msgfmt >/dev/null || { echo "msgfmt is required (package gettext)" >&2; exit 2; }
mkdir -p "$out"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT

# Everything that `gnome-extensions pack` does not pick up by itself is listed explicitly: no stray file reaches the zip.
extra=()
for f in "$SRC"/*.js "$SRC/m3e"; do
    case "$(basename "$f")" in
        extension.js|prefs.js) ;;
        *) extra+=("--extra-source=$f") ;;
    esac
done
gnome-extensions pack --force --quiet --out-dir "$work" --podir="$ROOT/po" --gettext-domain=window-magnet \
    --schema="schemas/org.gnome.shell.extensions.window-magnet.gschema.xml" "${extra[@]}" "$SRC"
zip="$work/$UUID.shell-extension.zip"
[[ -f "$zip" ]] || { echo "gnome-extensions pack produced no $zip" >&2; exit 1; }
# Reproducible bytes (the checksum pinned in install.sh) and no compiled schema (see normalize-zip.py).
python3 "$ROOT/scripts/normalize-zip.py" "$zip"
python3 "$ROOT/scripts/check-zip.py" "$zip"
mv -f "$zip" "$out/"
echo "packed $out/$UUID.shell-extension.zip"
