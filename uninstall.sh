#!/usr/bin/env bash
# Remove Window Magnet for the current user.
#
#   curl -fsSL https://raw.githubusercontent.com/maximeallanic/window-magnet/main/uninstall.sh | bash
#   ./uninstall.sh [--purge] [--dry-run]
#
# Disables the extension (the Shell undoes everything it changed: no window stays offset), removes it, and takes it
# out of the enabled list. --purge also resets its settings (dconf path /org/gnome/shell/extensions/window-magnet/).
# A copy installed system-wide (by a distribution package) is left alone: remove it with your package manager.
set -euo pipefail

UUID=window-magnet@maximeallanic.github.io
SETTINGS_PATH=/org/gnome/shell/extensions/window-magnet/
purge=0; dry=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --purge) purge=1 ;;
        --dry-run) dry=1 ;;
        -h|--help) sed -n '2,10p' "${BASH_SOURCE[0]:-$0}" 2>/dev/null | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
    esac
    shift
done

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
run() { if [[ $dry -eq 1 ]]; then echo "would run: $*"; else "$@"; fi; }
[[ $EUID -ne 0 ]] || { echo "error: run this as your own user, not with sudo" >&2; exit 1; }

user_dir="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$UUID"

if command -v gnome-extensions >/dev/null; then
    run gnome-extensions disable "$UUID" 2>/dev/null || true
    # Asks the running Shell to unload and delete it; fails when the Shell never loaded it (installed, no login yet).
    run gnome-extensions uninstall "$UUID" 2>/dev/null || true
fi
if [[ -d "$user_dir" ]]; then
    run rm -rf -- "$user_dir"
fi

list="$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null || echo '')"
if [[ "$list" == *"'$UUID'"* ]]; then
    list="$(sed -e "s/'$UUID'//" -e 's/, *,/,/g; s/\[ *, */[/; s/, *\]/]/' <<<"$list")"
    [[ "$list" == "[]" ]] && list="@as []"
    run gsettings set org.gnome.shell enabled-extensions "$list"
fi
if [[ $purge -eq 1 ]]; then
    run dconf reset -f "$SETTINGS_PATH"
    say "Settings reset"
fi

if [[ -d "/usr/share/gnome-shell/extensions/$UUID" ]]; then
    echo "note: a system-wide copy remains in /usr/share/gnome-shell/extensions/$UUID (package manager)" >&2
fi
say "Window Magnet removed."
