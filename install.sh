#!/usr/bin/env bash
# Install Window Magnet for the current user (no root, no build tools).
#
#   curl -fsSL https://raw.githubusercontent.com/maximeallanic/window-magnet/main/install.sh | bash
#   ./install.sh [--from-source] [--zip FILE] [--no-enable] [--dry-run]
#
# Default: downloads the pinned release zip from GitHub, checks its SHA-256 against the value pinned below, installs
# it with `gnome-extensions install` and enables it (now if GNOME Shell already knows it, otherwise at the next login).
#   --from-source  build the zip from this checkout (scripts/pack.sh) instead of downloading it
#   --zip FILE     install this zip (e.g. downloaded by hand from the releases page); no checksum is pinned for it
#   --no-enable    install only
#   --dry-run      print what would be done, change nothing
# Uninstall: ./uninstall.sh (or curl -fsSL .../uninstall.sh | bash). Check: ./verify.sh.
set -euo pipefail

UUID=window-magnet@maximeallanic.github.io
REPO=maximeallanic/window-magnet
VERSION=0.1.0
# SHA-256 of the release zip of $VERSION (scripts/release.sh writes it; the release workflow checks the uploaded zip).
ZIP_SHA256=f9e01990f2b8e9134a3235316363afcfe332ada64054ce3eab920841e026036c
SUPPORTED_SHELL=(50 51)

from_source=0; zip_file=''; enable=1; dry=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --from-source) from_source=1 ;;
        --zip) zip_file="${2:?--zip needs a file}"; shift ;;
        --no-enable) enable=0 ;;
        --dry-run) dry=1 ;;
        -h|--help) sed -n '2,13p' "${BASH_SOURCE[0]:-$0}" 2>/dev/null | sed 's/^# \{0,1\}//' ||
            echo "see https://github.com/$REPO#install"; exit 0 ;;
        *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
    esac
    shift
done

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }
run() { if [[ $dry -eq 1 ]]; then echo "would run: $*"; else "$@"; fi; }

[[ $EUID -ne 0 ]] || fail "run this as your own user, not with sudo: extensions are installed per user"
command -v gnome-extensions >/dev/null || fail "gnome-extensions not found: is GNOME Shell installed? (Debian/Ubuntu: gnome-shell, Fedora: gnome-shell)"

# GNOME Shell version: a mismatch is reported, not refused (the Shell itself refuses to load an unsupported version).
shell_major="$(LC_ALL=C gnome-shell --version 2>/dev/null | sed -n 's/^GNOME Shell \([0-9]*\).*/\1/p')"
if [[ -z "$shell_major" ]]; then
    echo "warning: could not read the GNOME Shell version" >&2
elif [[ " ${SUPPORTED_SHELL[*]} " != *" $shell_major "* ]]; then
    echo "warning: GNOME Shell $shell_major is not in the supported list (${SUPPORTED_SHELL[*]}): the Shell will not load the extension" >&2
fi

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT

if [[ $from_source -eq 1 ]]; then
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    [[ -x "$here/scripts/pack.sh" ]] || fail "--from-source needs a git checkout of $REPO"
    say "Building the zip from $here"
    run "$here/scripts/pack.sh" --out "$work"
    zip_file="$work/$UUID.shell-extension.zip"
elif [[ -z "$zip_file" ]]; then
    [[ "$ZIP_SHA256" =~ ^[0-9a-f]{64}$ ]] || fail "this copy of install.sh has no pinned checksum: use --from-source in a checkout"
    command -v curl >/dev/null || fail "curl is required to download the release"
    url="https://github.com/$REPO/releases/download/v$VERSION/$UUID.shell-extension.zip"
    zip_file="$work/$UUID.shell-extension.zip"
    say "Downloading Window Magnet $VERSION"
    run curl -fsSL --proto '=https' --tlsv1.2 -o "$zip_file" "$url"
    if [[ $dry -eq 0 ]]; then
        actual="$(sha256sum "$zip_file" | cut -d' ' -f1)"
        [[ "$actual" == "$ZIP_SHA256" ]] || fail "checksum mismatch for $url (expected $ZIP_SHA256, got $actual): nothing installed"
        say "Checksum verified"
    fi
else
    [[ -f "$zip_file" ]] || fail "no such file: $zip_file"
fi

# An update replaces the files, but the running Shell keeps the code it loaded until the next login.
updating=0
[[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$UUID/metadata.json" ]] && updating=1
say "Installing $UUID"
run gnome-extensions install --force "$zip_file"

if [[ $enable -eq 1 ]]; then
    if [[ "$(gsettings get org.gnome.shell disable-user-extensions 2>/dev/null)" == true ]]; then
        echo "note: user extensions are switched off globally (Extensions app, top switch); turn them on to use Window Magnet" >&2
    fi
    if [[ $dry -eq 0 ]] && gnome-extensions enable "$UUID" 2>/dev/null; then
        if [[ $updating -eq 1 ]]; then
            say "Updated. Log out and back in once to load the new version."
        else
            say "Enabled. Move a window near another one to try it."
        fi
    else
        # The running Shell only discovers a newly installed extension at the next login (Wayland). Writing the
        # enabled list makes it start then.
        list="$(gsettings get org.gnome.shell enabled-extensions)"
        if [[ "$list" != *"'$UUID'"* ]]; then
            if [[ "$list" == "@as []" || "$list" == "[]" ]]; then list="['$UUID']"; else list="${list%]}, '$UUID']"; fi
            run gsettings set org.gnome.shell enabled-extensions "$list"
        fi
        # An entry in disabled-extensions wins over enabled-extensions: drop it (the list holds UUIDs, no quotes).
        disabled="$(gsettings get org.gnome.shell disabled-extensions)"
        if [[ "$disabled" == *"'$UUID'"* ]]; then
            disabled="$(sed -e "s/'$UUID'//" -e 's/, *,/,/g; s/\[ *, */[/; s/, *\]/]/' <<<"$disabled")"
            [[ "$disabled" == "[]" ]] && disabled="@as []"
            run gsettings set org.gnome.shell disabled-extensions "$disabled"
        fi
        say "Installed. Log out and back in once: GNOME Shell loads new extensions at login. Then run verify.sh:"
        echo "    curl -fsSL https://raw.githubusercontent.com/$REPO/main/verify.sh | bash"
    fi
else
    say "Installed (not enabled). Enable it with: gnome-extensions enable $UUID"
fi
echo "Settings: gnome-extensions prefs $UUID (or the Extensions app)."
