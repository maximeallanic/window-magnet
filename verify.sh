#!/usr/bin/env bash
# Check that Window Magnet is installed and running, and say what to do when it is not. Changes nothing.
#
#   curl -fsSL https://raw.githubusercontent.com/maximeallanic/window-magnet/main/verify.sh | bash
#   ./verify.sh
# Exit code: 0 when everything is fine, 1 otherwise.
set -uo pipefail

UUID=window-magnet@maximeallanic.github.io
SCHEMA=org.gnome.shell.extensions.window-magnet
SUPPORTED_SHELL=(51)
status=0
ok() { printf '  \033[32mok\033[0m    %s\n' "$*"; }
bad() { printf '  \033[31mfail\033[0m  %s\n' "$1"; [[ -n "${2:-}" ]] && printf '        -> %s\n' "$2"; status=1; }
warn() { printf '  \033[33mnote\033[0m  %s\n' "$1"; [[ -n "${2:-}" ]] && printf '        -> %s\n' "$2"; }

echo "Window Magnet check"

shell_major="$(LC_ALL=C gnome-shell --version 2>/dev/null | sed -n 's/^GNOME Shell \([0-9]*\).*/\1/p')"
if [[ -z "$shell_major" ]]; then
    bad "GNOME Shell not found" "Window Magnet is a GNOME Shell extension"
elif [[ " ${SUPPORTED_SHELL[*]} " == *" $shell_major "* ]]; then
    ok "GNOME Shell $shell_major is supported"
else
    bad "GNOME Shell $shell_major is not supported (supported: ${SUPPORTED_SHELL[*]})" \
        "see https://github.com/maximeallanic/window-magnet#compatibility"
fi

case "${XDG_SESSION_TYPE:-}" in
    wayland|x11) ok "session: ${XDG_SESSION_TYPE}" ;;
    *) warn "not run from a graphical GNOME session (XDG_SESSION_TYPE='${XDG_SESSION_TYPE:-}')" \
        "run this script from a terminal inside your GNOME session" ;;
esac

dir=''
for d in "${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$UUID" "/usr/share/gnome-shell/extensions/$UUID"; do
    [[ -f "$d/metadata.json" ]] && { dir="$d"; break; }
done
if [[ -n "$dir" ]]; then
    ok "installed in $dir"
    if [[ -f "$dir/schemas/$SCHEMA.gschema.xml" ]] &&
        gsettings --schemadir "$dir/schemas" list-keys "$SCHEMA" >/dev/null 2>&1; then
        ok "settings schema readable"
    else
        bad "settings schema missing or not compiled in $dir/schemas" "reinstall with install.sh"
    fi
else
    bad "not installed" "run: curl -fsSL https://raw.githubusercontent.com/maximeallanic/window-magnet/main/install.sh | bash"
fi

if [[ "$(gsettings get org.gnome.shell disable-user-extensions 2>/dev/null)" == true ]]; then
    bad "all user extensions are switched off" "turn on the main switch of the Extensions app"
fi
enabled="$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null)"
if [[ "$enabled" == *"'$UUID'"* ]]; then
    ok "enabled in your settings"
else
    bad "not enabled" "run: gnome-extensions enable $UUID"
fi

# State as GNOME Shell sees it (the text of `gnome-extensions info` is localised: read it in C).
state="$(LC_ALL=C gnome-extensions info "$UUID" 2>/dev/null | sed -n 's/^ *State: *//p')"
case "$state" in
    ACTIVE) ok "running in GNOME Shell" ;;
    '') bad "GNOME Shell does not know the extension yet" "log out and back in once (Wayland loads new extensions at login)" ;;
    ERROR) bad "GNOME Shell reported an error while loading it" \
        "journalctl --user -b -o cat /usr/bin/gnome-shell | grep -i -A5 window-magnet   (and open an issue with it)" ;;
    "OUT OF DATE") bad "GNOME Shell says it does not support this Shell version" "see the compatibility table" ;;
    INACTIVE) bad "loaded but not active" "enable it: gnome-extensions enable $UUID" ;;
    *) bad "state: $state" "wait a few seconds and run this again; if it stays, log out and back in" ;;
esac

if [[ "$(gsettings get org.gnome.desktop.interface enable-animations 2>/dev/null)" == false ]]; then
    warn "system animations are off: snapping works, without the spring" "Settings > Accessibility > Seeing > Reduce Animation"
fi

if [[ $status -eq 0 ]]; then
    echo "All good. Drag a window close to another one: its edge snaps."
else
    echo "Something needs attention (see above)."
fi
exit $status
