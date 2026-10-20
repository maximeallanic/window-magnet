#!/usr/bin/env bash
# Runs a scenario of dev/nested/scenes.py inside an isolated, headless GNOME Shell with Window Magnet installed from
# its release zip. Nothing of the real session is used or changed: virtual monitor (--headless), named Wayland socket,
# private HOME, XDG_* and XDG_RUNTIME_DIR, private session bus (dbus-run-session), private system bus with a fake
# logind (python-dbusmock), private dconf database. Only the host's PipeWire socket is reachable (PIPEWIRE_RUNTIME_DIR):
# the Shell's screencast of the demo scenario streams through it.
#
#   dev/nested/nested.sh --scenario e2e|demo|prefs --out DIR [--zip ZIP] [--size 1280x720]
#
# --zip   the extension zip to test (default: built with scripts/pack.sh into DIR)
# Exit: 0 ok, 1 the scenario failed, 2 usage or refusal, 3 the real dconf database changed during the run.
# Adapted from tests/bench/nested.sh of m3e-gnome-extensions (same author, MIT).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
UUID=window-magnet@maximeallanic.github.io
DRIVER=driver@window-magnet.test
DRIVER_NAME=io.github.maximeallanic.WindowMagnetDriver
DRIVER_PATH=/io/github/maximeallanic/WindowMagnetDriver

if [[ "${1:-}" != --inner ]]; then
    SCENARIO=''; OUT=''; ZIP=''; SIZE=1280x720
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --scenario) SCENARIO="${2:?}"; shift 2 ;;
            --out) OUT="${2:?}"; shift 2 ;;
            --zip) ZIP="${2:?}"; shift 2 ;;
            --size) SIZE="${2:?}"; shift 2 ;;
            *) echo "unknown option: $1" >&2; exit 2 ;;
        esac
    done
    [[ "$SCENARIO" =~ ^[a-z0-9-]+$ && -n "$OUT" && "$SIZE" =~ ^[0-9]+x[0-9]+$ ]] ||
        { echo "usage: nested.sh --scenario NAME --out DIR [--zip ZIP] [--size WxH]" >&2; exit 2; }
    for tool in gnome-shell dbus-run-session dbus-daemon gdbus dconf; do
        command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 2; }
    done
    python3 -c 'import dbusmock' 2>/dev/null || { echo "python3-dbusmock is required" >&2; exit 2; }
    mkdir -p "$OUT" && OUT="$(cd "$OUT" && pwd)" || exit 2
    if [[ -z "$ZIP" ]]; then
        "$ROOT/scripts/pack.sh" --out "$OUT" >/dev/null || exit 2
        ZIP="$OUT/$UUID.shell-extension.zip"
    fi
    [[ -f "$ZIP" ]] || { echo "no such zip: $ZIP" >&2; exit 2; }
    ZIP="$(cd "$(dirname "$ZIP")" && pwd)/$(basename "$ZIP")"
    # dconf guard: the real database must not change because of the bench (the real session may write too).
    DCONF_REAL="${XDG_CONFIG_HOME:-$HOME/.config}/dconf/user"
    dconf_date() { stat -c '%y' "$DCONF_REAL" 2>/dev/null || echo absent; }
    DCONF_BEFORE="$(dconf_date)"
    HOST_RUN="${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}"
    TMP="$(mktemp -d)" || exit 2
    mkdir -m 0700 "$TMP/run" && mkdir -p "$TMP/home" || exit 2
    # Exported BEFORE dbus-run-session: services activated on the private bus (dconf-service above all) inherit the
    # environment of the bus daemon, so they write into TMP and never into the real ~/.config/dconf.
    export XDG_RUNTIME_DIR="$TMP/run" HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/config" XDG_DATA_HOME="$TMP/data" \
        XDG_CACHE_HOME="$TMP/cache" XDG_STATE_HOME="$TMP/state" WM_NESTED_TMP="$TMP" \
        WM_NESTED_REAL_BUS="${DBUS_SESSION_BUS_ADDRESS:-}" PIPEWIRE_RUNTIME_DIR="$HOST_RUN"
    unset WAYLAND_DISPLAY DISPLAY DBUS_SYSTEM_BUS_ADDRESS
    dbus-run-session -- bash "$HERE/nested.sh" --inner "$SCENARIO" "$OUT" "$ZIP" "$SIZE"
    code=$?
    # Leave nothing behind (mounts under TMP, e.g. a document portal, are lazily unmounted first).
    while read -r m; do fusermount3 -u -z "$m" 2>/dev/null || fusermount -u -z "$m" 2>/dev/null; done < <(
        awk -v t="$TMP/" 'index($2, t) == 1 { print $2 }' /proc/mounts)
    awk -v t="$TMP/" 'index($2, t) == 1 { f = 1 } END { exit !f }' /proc/mounts || rm -rf -- "$TMP"
    if [[ "$(dconf_date)" != "$DCONF_BEFORE" ]]; then
        echo "nested.sh: $DCONF_REAL changed during the run: please check (the real session may write too)" >&2
        code=3
    fi
    exit $code
fi

# --- inner part: inside the private session bus ---
SCENARIO="$2"; OUT="$3"; ZIP="$4"; SIZE="$5"
refuse() { echo "nested.sh --inner refused: $1" >&2; exit 2; }
TMP="${WM_NESTED_TMP:-}"
[[ -n "$TMP" && -d "$TMP/run" && "$XDG_RUNTIME_DIR" == "$TMP/run" && "$HOME" == "$TMP/home" ]] || refuse "not private"
for v in XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME; do
    [[ "${!v}" == "$TMP"/* ]] || refuse "$v is not private"
done
[[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" && "$DBUS_SESSION_BUS_ADDRESS" != "${WM_NESTED_REAL_BUS:-}" ]] || refuse "real session bus"

PIDS=()
# shellcheck disable=SC2317,SC2329  # invoked by the EXIT trap
cleanup() {
    local p
    for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done
    for p in "${PIDS[@]}"; do
        for _ in $(seq 1 50); do kill -0 "$p" 2>/dev/null || break; sleep 0.1; done
        kill -9 "$p" 2>/dev/null
    done
}
trap cleanup EXIT

# Private system bus with a fake logind: the nested Shell never talks to the real login session.
dbus-daemon --session --nofork --address="unix:path=$TMP/system_bus" >"$OUT/system-bus.log" 2>&1 &
PIDS+=($!)
for _ in $(seq 1 50); do [[ -S "$TMP/system_bus" ]] && break; sleep 0.1; done
export DBUS_SYSTEM_BUS_ADDRESS="unix:path=$TMP/system_bus"
python3 -m dbusmock --system --template logind >"$OUT/logind.log" 2>&1 &
PIDS+=($!)
mock() { gdbus call --system --dest org.freedesktop.login1 --object-path /org/freedesktop/login1 \
    --method org.freedesktop.DBus.Mock."$1" "${@:2}" >/dev/null; }
for _ in $(seq 1 100); do mock AddSeat seat0 2>/dev/null && break; sleep 0.1; done
# python-dbusmock's GetUser concatenates a str and the uint32 argument (TypeError): redefined with str().
if ! { mock AddMethod org.freedesktop.login1.Manager GetUser u o 'ret = "/org/freedesktop/login1/user/" + str(args[0])' &&
    mock AddUser "$(id -u)" demo true && mock AddSession c1 seat0 "$(id -u)" demo true; }; then
    echo "fake logind setup failed (see $OUT/logind.log)" >&2
    exit 1
fi

# Window Magnet from its zip (the artefact users get), the driver from this directory.
gnome-extensions install --force "$ZIP" || { echo "gnome-extensions install failed" >&2; exit 1; }
cp -r "$HERE/$DRIVER" "$XDG_DATA_HOME/gnome-shell/extensions/$DRIVER"
mkdir -p "$TMP/dconf-src" "$XDG_CONFIG_HOME/dconf"
# No hot corner: the virtual pointer starts at the top-left corner and would open the overview at the first motion.
cat >"$TMP/dconf-src/nested.keyfile" <<K
[org/gnome/shell]
enabled-extensions=['$DRIVER', '$UUID']
disable-user-extensions=false
welcome-dialog-last-shown-version='999'

[org/gnome/desktop/interface]
enable-animations=true
color-scheme='prefer-dark'
clock-show-date=false
enable-hot-corners=false

[org/gnome/desktop/background]
picture-uri=''
picture-uri-dark=''
picture-options='none'
color-shading-type='solid'
primary-color='#2b2d42'

[org/gnome/desktop/screensaver]
lock-enabled=false
idle-activation-enabled=false

[org/gnome/desktop/session]
idle-delay=uint32 0

[org/gnome/desktop/notifications]
show-banners=false

[org/gnome/desktop/sound]
event-sounds=false

[org/gnome/desktop/search-providers]
disable-external=true
K
dconf compile "$XDG_CONFIG_HOME/dconf/user" "$TMP/dconf-src" || { echo "dconf compile failed" >&2; exit 1; }

DISPLAY_NAME="window-magnet-nested-$$"
env -u LANGUAGE LANG=C.UTF-8 LC_ALL=C.UTF-8 WM_NESTED_OUT="$OUT" WM_NESTED_SCRIPTS="$HERE" \
    gnome-shell --headless --virtual-monitor "$SIZE@60" --wayland --wayland-display "$DISPLAY_NAME" \
    >"$OUT/shell.log" 2>&1 &
SHELL_PID=$!
PIDS+=("$SHELL_PID")

call() { gdbus call --session --dest "$DRIVER_NAME" --object-path "$DRIVER_PATH" --method "$DRIVER_NAME.$1" "${@:2}" 2>&1; }
ready=0
for _ in $(seq 1 240); do
    kill -0 "$SHELL_PID" 2>/dev/null || { echo "the nested Shell stopped (see $OUT/shell.log)" >&2; exit 1; }
    if call Ping >/dev/null; then ready=1; break; fi
    sleep 0.5
done
[[ $ready -eq 1 ]] || { echo "driver not ready (see $OUT/shell.log)" >&2; exit 1; }

call Run "$SCENARIO" >/dev/null || { echo "Run $SCENARIO failed" >&2; exit 1; }
result=''
for _ in $(seq 1 2400); do   # up to 10 minutes: a loaded machine is slow
    reply="$(call Result "$SCENARIO")" || { echo "Result failed: $reply" >&2; exit 1; }
    result="$(python3 -c 'import ast, sys; print(ast.literal_eval(sys.stdin.read().strip())[0])' <<<"$reply")"
    [[ -n "$result" ]] && break
    sleep 0.25
done
[[ -n "$result" ]] || { echo "scenario $SCENARIO: no result (see $OUT/scene-$SCENARIO.log)" >&2; exit 1; }
echo "$result" >"$OUT/result-$SCENARIO.json"
if python3 -c 'import json, sys; sys.exit(0 if json.load(open(sys.argv[1]))["ok"] else 1)' "$OUT/result-$SCENARIO.json"; then
    echo "scenario $SCENARIO: ok"
else
    echo "scenario $SCENARIO: FAILED (see $OUT/scene-$SCENARIO.log and $OUT/shell.log)" >&2
    exit 1
fi
