#!/usr/bin/env python3
"""Scenarios played inside the nested Shell of nested.sh (started by the driver extension, on the private bus).

  e2e   end-to-end checks of the installed extension: snapping to a window, release, screen edge, settings,
        resize, spring offset back to 0, disable / enable. Writes <out>/e2e.json; exit 1 on any failed check.
  demo  the README recording: org.gnome.Shell.Screencast of the nested Shell, scenes in slow motion (see SLOW),
        marks in <out>/demo-marks.json for dev/nested/make-media.sh.
  prefs the preferences window, captured to <out>/prefs.png with its frame in <out>/prefs.json; its language is
        WM_PREFS_LANG (a locale such as fr_FR.UTF-8, default C.UTF-8).

Usage: scenes.py OUT_DIR SCENARIO
"""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

from gi.repository import Gio, GLib

NAME = "io.github.maximeallanic.WindowMagnetDriver"
PATH = "/io/github/maximeallanic/WindowMagnetDriver"
BUS = Gio.bus_get_sync(Gio.BusType.SESSION, None)
HERE = Path(__file__).resolve().parent
UUID = "window-magnet@maximeallanic.github.io"
TOP_BAR = 32          # height reserved by the top bar at scale 1: the work area starts below it
SLOW = 1              # demo: slow-down factor of the Shell's animations; every pause and glide is multiplied by it


def call(method, signature=None, *args, timeout=20000):
    params = GLib.Variant(signature, args) if signature else None
    reply = BUS.call_sync(NAME, PATH, NAME, method, params, None, Gio.DBusCallFlags.NONE, timeout, None)
    return reply.unpack() if reply is not None else ()


def pause(seconds):
    time.sleep(seconds * SLOW)


def windows():
    return {w["title"]: w for w in json.loads(call("Windows")[0])}


def window(title):
    return windows()[title]


def glide(x, y, seconds):
    call("Glide", "(ddd)", float(x), float(y), float(seconds * SLOW))
    pause(seconds + 0.05)


def button(pressed):
    call("Button", "(ub)", 1, pressed)


def drag(start, moves, hold=0.15):
    """Press at `start`, glide through `moves` [(x, y, seconds)], release. Returns the frames seen just before release."""
    call("Pointer", "(dd)", float(start[0]), float(start[1]))
    pause(0.1)
    button(True)
    pause(hold)
    for x, y, seconds in moves:
        glide(x, y, seconds)
    pause(0.2)
    before = windows()
    button(False)
    pause(0.3)
    return before


def grip(w):
    """A point of the header bar of window `w` (away from the title and the buttons)."""
    return w["x"] + 70, w["y"] + 18


def setting(key, value):
    call("SetSetting", "(ss)", key, json.dumps(value))
    time.sleep(0.2)


def wait_until(predicate, timeout=5.0):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if predicate():
            return True
        time.sleep(0.05)
    return predicate()


def desktop():
    """Leaves the overview the Shell shows at start-up, and waits until nothing is modal."""
    def hidden_for_a_while():
        call("HideOverview")
        time.sleep(1.0)
        state = json.loads(call("ShellState")[0])
        return not state["overview"] and state["modalCount"] == 0
    if not wait_until(hidden_for_a_while, 20):
        raise RuntimeError(f"overview still visible: {call('ShellState')[0]}")


class Apps:
    """The demo windows (client.py), started in their own process group and stopped by it."""

    def __init__(self, specs):
        env = {**os.environ, "NO_AT_BRIDGE": "1", "GTK_A11Y": "none"}
        self.proc = subprocess.Popen([sys.executable, str(HERE / "client.py"), *[f"{t}={c}" for t, c in specs]],
                                     start_new_session=True, env=env)
        titles = [t for t, _c in specs]
        if not wait_until(lambda: all(windows().get(t, {}).get("w", 0) > 0 for t in titles), 60):
            raise RuntimeError(f"windows did not appear: {list(windows())}")
        time.sleep(1.0)     # first frames and Mutter's initial placement done before anything is moved
        desktop()

    def close(self):
        os.killpg(self.proc.pid, 15)
        self.proc.wait(10)


def place(title, x, y, w, h):
    """Moves and resizes a window and waits until its frame is exactly there (the client commits the size later)."""
    def there():
        r = window(title)
        return (r["x"], r["y"], r["w"], r["h"]) == (x, y, w, h)
    for _attempt in range(5):
        call("Place", "(uiiii)", window(title)["id"], x, y, w, h)
        if wait_until(there, 3):
            time.sleep(0.2)
            return
    raise RuntimeError(f"cannot place {title}: {window(title)}")


class Checks:
    def __init__(self):
        self.items = []

    def check(self, name, ok, detail=""):
        self.items.append({"name": name, "ok": bool(ok), "detail": detail})
        print(f"{'PASS' if ok else 'FAIL'}  {name}  {detail}", flush=True)

    @property
    def ok(self):
        return all(i["ok"] for i in self.items)


def e2e(out):
    c = Checks()
    apps = Apps([("A", "#d0bcff"), ("B", "#a8dab5")])
    try:
        place("A", 80, 140, 400, 300)
        place("B", 700, 140, 400, 300)
        a = window("A")
        x0, y0 = grip(a)
        # 1. Right edge of A brought 10 px short of B's left edge: snapped while held, kept on release.
        held = drag((x0, y0), [(x0 + 210, y0 + 3, 0.6)])
        c.check("move: snaps to the other window while held", held["A"]["x"] + held["A"]["w"] == 700,
                f"A.x={held['A']['x']} w={held['A']['w']}")
        a = window("A")
        c.check("move: stays snapped after release", a["x"] + a["w"] == 700, f"A.x={a['x']}")
        c.check("move: top edges aligned (3 px apart)", a["y"] == 140, f"A.y={a['y']}")
        c.check("spring: translation back to 0",
                wait_until(lambda: (lambda w: abs(w["tx"]) < 0.01 and abs(w["ty"]) < 0.01)(window("A")), 3),
                json.dumps(window("A")))
        # 2. Pulled 60 px away: free again, follows the pointer exactly.
        x0, y0 = grip(a)
        drag((x0, y0), [(x0 - 60, y0 + 40, 0.4)])
        a = window("A")
        c.check("move: released beyond the threshold", (a["x"], a["y"]) == (300 - 60, 180), f"A=({a['x']}, {a['y']})")
        # 3. Screen edge: 9 px from the left edge of the work area.
        x0, y0 = grip(a)
        drag((x0, y0), [(x0 - 231, y0, 0.5)])
        a = window("A")
        c.check("move: snaps to the screen edge", a["x"] == 0, f"A.x={a['x']}")
        # 4. Settings: snap-to-windows off, then a 4 px threshold.
        place("A", 280, 300, 400, 300)
        setting("snap-to-windows", False)
        a = window("A")
        x0, y0 = grip(a)
        drag((x0, y0), [(x0 + 10, y0, 0.3)])
        a = window("A")
        c.check("setting snap-to-windows=false: no snap", a["x"] + a["w"] == 690, f"A.x={a['x']}")
        setting("snap-to-windows", True)
        setting("snap-threshold", 4)
        place("A", 280, 300, 400, 300)
        x0, y0 = grip(window("A"))
        drag((x0, y0), [(x0 + 10, y0, 0.3)])
        a = window("A")
        c.check("setting snap-threshold=4: 10 px gap does not snap", a["x"] + a["w"] == 690, f"A.x={a['x']}")
        setting("snap-threshold", 16)
        # 5. Resize: east edge of A dragged to 8 px short of B (GTK's resize border lies just outside the frame).
        place("A", 80, 140, 400, 300)
        a = window("A")
        held = drag((a["x"] + a["w"] + 4, a["y"] + 150), [(a["x"] + a["w"] + 4 + 212, a["y"] + 150, 0.6)])
        a = window("A")
        c.check("resize: east edge snaps to the other window", a["x"] == 80 and a["x"] + a["w"] == 700,
                f"held w={held['A']['w']}, after: x={a['x']} w={a['w']}")
        # 6. Disable while a spring may run, then enable: nothing stays offset, the extension comes back.
        place("A", 80, 140, 400, 300)
        x0, y0 = grip(window("A"))
        call("Pointer", "(dd)", float(x0), float(y0))
        button(True)
        pause(0.15)
        glide(x0 + 212, y0, 0.4)
        call("SetEnabled", "(b)", False)
        button(False)
        state = json.loads(call("State")[0])
        c.check("disable: extension inactive", state["state"] == 2, json.dumps(state))
        w = window("A")
        c.check("disable: no translation left", w["tx"] == 0 and w["ty"] == 0, json.dumps(w))
        # Released while disabled, the window ends where the pointer put it, unsnapped (x0 - 70 + 212). Mutter may
        # apply that final move well after the release (GNOME Shell 50 does, late enough to undo the place() below):
        # wait for it before going on.
        if not wait_until(lambda: window("A")["x"] == x0 - 70 + 212, 5):
            print(f"note: A did not settle at its released position: {json.dumps(window('A'))}", flush=True)
        call("SetEnabled", "(b)", True)
        wait_until(lambda: json.loads(call("State")[0])["state"] == 1, 5)
        state = json.loads(call("State")[0])
        c.check("enable: active again, no error", state["state"] == 1 and not state["error"], json.dumps(state))
        place("A", 80, 140, 400, 300)
        x0, y0 = grip(window("A"))
        drag((x0, y0), [(x0 + 212, y0, 0.5)])
        a = window("A")
        c.check("enable: snapping works again", a["x"] + a["w"] == 700, f"A.x={a['x']}")
    finally:
        apps.close()
    (Path(out) / "e2e.json").write_text(json.dumps({"ok": c.ok, "checks": c.items}, indent=1), encoding="utf-8")
    return 0 if c.ok else 1


SCREENCAST = ("org.gnome.Shell.Screencast", "/org/gnome/Shell/Screencast", "org.gnome.Shell.Screencast")


def screencast(method, signature=None, *args):
    params = GLib.Variant(signature, args) if signature else None
    return BUS.call_sync(*SCREENCAST, method, params, None, Gio.DBusCallFlags.NONE, 20000, None).unpack()


def demo(out):
    """Snap to a window (spring), align the tops, pull away, snap to the screen edge, resize against a window."""
    global SLOW
    out = Path(out)
    apps = Apps([("Drag me", "#d0bcff"), ("Notes", "#a8dab5"), ("Music", "#ffd8a8")])
    try:
        place("Notes", 760, 70, 440, 290)
        place("Music", 760, 380, 440, 280)
        place("Drag me", 110, 200, 400, 300)
        call("HideRecordingIndicator")
        call("Pointer", "(dd)", 640.0, 700.0)
        time.sleep(1.5)
        SLOW = int(os.environ.get("WM_DEMO_SLOWDOWN", "3"))
        call("SlowDown", "(d)", float(SLOW))
        ok, path = screencast("Screencast", "(sa{sv})", str(out / "demo-raw"),
                              {"framerate": GLib.Variant("i", 60), "draw-cursor": GLib.Variant("b", True)})
        if not ok:
            raise RuntimeError("Screencast refused")
        t0 = time.monotonic()
        pause(0.6)
        w = window("Drag me")
        gx, gy = grip(w)
        glide(gx, gy, 0.6)
        button(True)
        pause(0.25)
        # Towards "Notes": the right edge snaps to its left edge (spring), then the tops align.
        glide(gx + 200, gy - 60, 1.0)
        glide(gx + 236, gy - 128, 0.8)
        pause(0.5)
        # Pulled away: free again, the spring catches the jump back.
        glide(gx + 120, gy - 40, 0.7)
        # Down to "Music": bottom edges align, right edge snaps again.
        glide(gx + 240, gy + 150, 1.0)
        pause(0.5)
        # Over to the left edge of the screen.
        glide(gx - 100, gy + 140, 1.0)
        pause(0.4)
        button(False)
        pause(0.6)
        # Resize: the east edge of the window grows until it snaps to "Notes" / "Music".
        w = window("Drag me")
        ex, ey = w["x"] + w["w"] + 4, w["y"] + w["h"] // 2
        glide(ex, ey, 0.6)
        button(True)
        pause(0.2)
        glide(752 + 4, ey + 10, 1.2)
        pause(0.5)
        button(False)
        pause(0.8)
        glide(640, 700, 0.6)
        pause(0.4)
        duration = time.monotonic() - t0
        screencast("StopScreencast")
        marks = {"file": Path(path).name, "slowdown": SLOW, "duration": round(duration, 3)}
        (out / "demo-marks.json").write_text(json.dumps(marks, indent=1), encoding="utf-8")
    finally:
        call("SlowDown", "(d)", 1.0)
        apps.close()
    return 0


def prefs(out):
    """Opens the preferences window through the Shell, like the Extensions app does, and captures it."""
    out = Path(out)
    lang = os.environ.get("WM_PREFS_LANG", "C.UTF-8")
    desktop()
    # The preferences run in org.gnome.Shell.Extensions, a D-Bus activated service: it takes its display and its
    # locale from the activation environment of the (private) bus.
    env = {"WAYLAND_DISPLAY": os.environ["WAYLAND_DISPLAY"], "LANG": lang, "LC_ALL": lang, "LANGUAGE": "",
           "GTK_A11Y": "none", "NO_AT_BRIDGE": "1"}     # no accessibility bus in the nested session
    BUS.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                  "UpdateActivationEnvironment", GLib.Variant("(a{ss})", (env,)), None,
                  Gio.DBusCallFlags.NONE, 20000, None)
    before = set(windows())
    t0 = time.monotonic()
    BUS.call_sync("org.gnome.Shell", "/org/gnome/Shell", "org.gnome.Shell.Extensions", "OpenExtensionPrefs",
                  GLib.Variant("(ssa{sv})", (UUID, "", {})), None, Gio.DBusCallFlags.NONE, 20000, None)
    if not wait_until(lambda: any(w["w"] > 0 for t, w in windows().items() if t not in before), 60):
        call("Capture", "(s)", str(out / "prefs-failed.png"))
        raise RuntimeError(f"no preferences window: {list(windows())} (screen in prefs-failed.png)")
    title = next(t for t in windows() if t not in before)
    print(f"preferences window {title!r} after {time.monotonic() - t0:.1f} s", flush=True)
    time.sleep(2.0)     # first frames, fonts and the window's opening animation
    call("Pointer", "(dd)", 1270.0, 710.0)
    time.sleep(0.5)
    call("Capture", "(s)", str(out / "prefs.png"))
    (out / "prefs.json").write_text(json.dumps({"lang": lang, **window(title)}, indent=1), encoding="utf-8")
    return 0


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    out, scenario = sys.argv[1:]
    if not os.environ.get("XDG_CONFIG_HOME", "").startswith(os.environ.get("WM_NESTED_TMP", "/nonexistent")):
        sys.exit("refusing to run outside the private nested session")
    scenes = {"e2e": e2e, "demo": demo, "prefs": prefs}
    if scenario not in scenes:
        sys.exit(f"unknown scenario {scenario}")
    sys.exit(scenes[scenario](out))


if __name__ == "__main__":
    main()
