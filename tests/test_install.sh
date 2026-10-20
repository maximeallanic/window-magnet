#!/usr/bin/env bash
# install.sh --zip, verify.sh and uninstall.sh against a throw-away HOME, with fake gsettings / gnome-shell and a
# gnome-extensions that cannot reach a Shell: nothing touches the real session, dconf or home.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UUID=window-magnet@maximeallanic.github.io
sandbox="$(mktemp -d)"
trap 'rm -rf -- "$sandbox"' EXIT
REAL_GNOME_EXTENSIONS="$(command -v gnome-extensions)"
REAL_GSETTINGS="$(command -v gsettings)"
export REAL_GNOME_EXTENSIONS REAL_GSETTINGS
export HOME="$sandbox/home" XDG_DATA_HOME="$sandbox/home/.local/share" FAKE_GSETTINGS="$sandbox/gsettings.db"
fail() { echo "FAIL: $*" >&2; exit 1; }
"$ROOT/scripts/pack.sh" --out "$sandbox/dist" >/dev/null || fail "pack.sh"
export PATH="$ROOT/tests/shims:$PATH"
unset DBUS_SESSION_BUS_ADDRESS
mkdir -p "$HOME"
zip="$sandbox/dist/$UUID.shell-extension.zip"
echo "org.gnome.shell enabled-extensions=['other@example.org']" >"$FAKE_GSETTINGS"
echo "org.gnome.shell disabled-extensions=['$UUID', 'x@example.org']" >>"$FAKE_GSETTINGS"

"$ROOT/install.sh" --zip "$zip" >"$sandbox/install.log" 2>&1 || { cat "$sandbox/install.log"; fail "install.sh"; }
dest="$XDG_DATA_HOME/gnome-shell/extensions/$UUID"
[[ -f "$dest/extension.js" && -f "$dest/m3e/animate.js" && -f "$dest/locale/fr/LC_MESSAGES/window-magnet.mo" ]] ||
    fail "files not installed in $dest"
grep -qF "enabled-extensions=['other@example.org', '$UUID']" "$FAKE_GSETTINGS" || fail "not added to enabled-extensions"
grep -qF "disabled-extensions=['x@example.org']" "$FAKE_GSETTINGS" || fail "not removed from disabled-extensions"
grep -q "Log out and back in" "$sandbox/install.log" || fail "no login hint"

# Shell not reached: verify.sh must fail and say why.
if "$ROOT/verify.sh" >"$sandbox/verify.log" 2>&1; then fail "verify.sh passed without a running Shell"; fi
grep -q "settings schema readable" "$sandbox/verify.log" || { cat "$sandbox/verify.log"; fail "schema not readable"; }
grep -q "log out and back in" "$sandbox/verify.log" || fail "verify.sh gave no hint"

# A second install is harmless (no duplicate entry).
"$ROOT/install.sh" --zip "$zip" >/dev/null 2>&1 || fail "second install.sh"
[[ "$(grep -o "'$UUID'" "$FAKE_GSETTINGS" | wc -l)" -eq 1 ]] || fail "duplicate enabled entry"

# Update while the Shell already runs the extension: the new code needs a new login, and the user is told so.
out="$(FAKE_SHELL_KNOWS=1 "$ROOT/install.sh" --zip "$zip" 2>&1)" || fail "update install"
grep -q "Updated. Log out and back in" <<<"$out" || { echo "$out"; fail "no update hint"; }

# Download path (fake curl): the pinned release URL is fetched and a checksum mismatch installs nothing.
export FAKE_DOWNLOAD="$zip" FAKE_CURL_LOG="$sandbox/curl.log"
version="$(sed -n 's/^VERSION=//p' "$ROOT/install.sh")"
sha="$(sha256sum "$zip" | cut -d' ' -f1)"
sed "s/^ZIP_SHA256=.*/ZIP_SHA256=$sha/" "$ROOT/install.sh" >"$sandbox/install-pinned.sh"
sed "s/^ZIP_SHA256=.*/ZIP_SHA256=$(printf '0%.0s' {1..64})/" "$ROOT/install.sh" >"$sandbox/install-wrong.sh"
"$ROOT/uninstall.sh" >/dev/null 2>&1 || fail "uninstall before the download test"
if bash "$sandbox/install-wrong.sh" >"$sandbox/wrong.log" 2>&1; then fail "a checksum mismatch was installed"; fi
grep -q "checksum mismatch" "$sandbox/wrong.log" || { cat "$sandbox/wrong.log"; fail "no mismatch message"; }
[[ ! -e "$dest" ]] || fail "files installed despite the checksum mismatch"
# Like `curl ... | bash`: the script comes on stdin.
bash <"$sandbox/install-pinned.sh" >"$sandbox/pinned.log" 2>&1 || { cat "$sandbox/pinned.log"; fail "pinned download install"; }
grep -q "Checksum verified" "$sandbox/pinned.log" || fail "checksum not reported"
[[ -f "$dest/extension.js" ]] || fail "pinned download not installed"
grep -qxF "https://github.com/maximeallanic/window-magnet/releases/download/v$version/$UUID.shell-extension.zip" \
    "$FAKE_CURL_LOG" || { cat "$FAKE_CURL_LOG"; fail "unexpected download URL"; }

# --dry-run must not write anything.
before="$(cat "$FAKE_GSETTINGS")"
"$ROOT/install.sh" --zip "$zip" --dry-run >/dev/null 2>&1 || fail "dry run"
[[ "$(cat "$FAKE_GSETTINGS")" == "$before" ]] || fail "dry run changed settings"

"$ROOT/uninstall.sh" >/dev/null 2>&1 || fail "uninstall.sh"
[[ ! -e "$dest" ]] || fail "$dest still there"
grep -qF "enabled-extensions=['other@example.org']" "$FAKE_GSETTINGS" || fail "not removed from enabled-extensions"
# Unsupported Shell: a warning, not a refusal.
out="$(FAKE_SHELL_VERSION=40.0 "$ROOT/install.sh" --zip "$zip" 2>&1)" || fail "install.sh on an unsupported Shell"
grep -q "not in the supported list" <<<"$out" || fail "no version warning"
echo "test_install: OK"
