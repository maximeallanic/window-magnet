#!/usr/bin/env bash
# Refresh the vendored motion toolkit (extension/m3e/) from a checkout of m3e-gnome-extensions, or check it.
#
#   scripts/update-m3e.sh CHECKOUT    copy CHECKOUT/shared/m3e/{animate,track,spring,curve,tokens}.js and rewrite
#                                     vendor/m3e.lock (commit of CHECKOUT, SHA-256 of each file)
#   scripts/update-m3e.sh --check     exit 1 if extension/m3e/ does not match vendor/m3e.lock
# Only the modules Window Magnet imports are vendored; they are never edited here.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK="$ROOT/vendor/m3e.lock"
DEST="$ROOT/extension/m3e"
FILES=(animate.js curve.js spring.js tokens.js track.js)

if [[ "${1:-}" == "--check" ]]; then
    expected="$(grep -E '^[0-9a-f]{64}  ' "$LOCK")"
    actual="$(cd "$DEST" && sha256sum -- *.js)"
    if [[ "$expected" != "$actual" ]]; then
        echo "extension/m3e/ differs from vendor/m3e.lock:" >&2
        diff <(echo "$expected") <(echo "$actual") >&2 || true
        exit 1
    fi
    echo "extension/m3e/ matches vendor/m3e.lock"
    exit 0
fi
src="${1:?usage: update-m3e.sh CHECKOUT | --check}"
[[ -d "$src/shared/m3e" ]] || { echo "$src is not an m3e-gnome-extensions checkout" >&2; exit 2; }
commit="$(git -C "$src" rev-parse HEAD)"
rm -f -- "${DEST:?}"/*.js
for f in "${FILES[@]}"; do cp -- "$src/shared/m3e/$f" "$DEST/$f"; done
{
    echo "# Vendored copy of the M3E motion toolkit. Refresh with scripts/update-m3e.sh <m3e-gnome-extensions checkout>."
    echo "source https://github.com/maximeallanic/m3e-gnome-extensions"
    echo "commit $commit"
    echo "path shared/m3e"
    (cd "$DEST" && sha256sum -- *.js)
} >"$LOCK"
echo "vendored m3e at $commit"
