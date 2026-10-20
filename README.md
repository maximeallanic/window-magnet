# Window Magnet

[![CI](https://github.com/maximeallanic/window-magnet/actions/workflows/ci.yml/badge.svg)](https://github.com/maximeallanic/window-magnet/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![GNOME Shell 50 | 51](https://img.shields.io/badge/GNOME%20Shell-50%20%7C%2051-4a86cf.svg)](#compatibility)

English | [Français](README.fr.md)

**Window edges that snap together, with a spring.** Drag a window close to another one, or to the side of the
screen, and it lands flush against that edge; keep pulling and it lets go. A GNOME Shell extension for people who
arrange their windows by hand and want them to line up.

![A window dragged next to two others: its right edge snaps to their left edge, its top edge aligns with the top of
the first one, then it is pulled away, snapped to the left edge of the screen and resized until it snaps again](media/demo.gif)

*Recorded in GNOME Shell 51 (nested, headless) at real speed. [MP4 version](media/demo.mp4).*

```sh
curl -fsSL https://raw.githubusercontent.com/maximeallanic/window-magnet/main/install.sh | bash
```

**GNOME Shell 50 and 51.** On Wayland, log out and back in once after the first install. This command downloads the
v0.1.0 release from GitHub: until that release is published it stops with a download error, so
[install from source](#from-source) instead. Not on extensions.gnome.org yet.

## Why this one

GNOME used to snap a dragged window to the edges of the others. Since GNOME 40 it only does so while you hold
**Ctrl** (Mutter's release notes: "Only snap to window edges when CTRL is pressed"). The change followed reports that
drags looked like they stuttered, because every nearby edge caught the window
([Ubuntu bug 1727225](https://bugs.launchpad.net/ubuntu/+source/gnome-shell/+bug/1727225)). Window Magnet brings
window-to-window snapping back without a modifier key, and changes what made it feel bad:

- **Snaps on a spring**: the window's real position snaps at once; what you see glides there on a short spring,
  so a snap reads as a pull rather than a stutter. It follows GNOME's *Reduce Animation* setting.
- **Holds, then lets go**: a snapped window stays put until the pointer moves further than the snap distance (16 px
  by default, 4 to 64), then it follows the pointer exactly again.
- **Only edges that face each other**: another window pulls a vertical edge only when the two overlap vertically,
  and the other way round, so a window far above does not grab yours.
- **Resizing snaps too, without flicker**: the edge you drag snaps in the same frame as GNOME's own resize, so the
  app never shows two sizes in a row.
- **A switch for each source**: turn off snapping to other windows, to screen edges or while resizing, or just the
  spring.

It also fixes one thing GNOME does not handle on Wayland: **a tab you drag out of a window and drop on the desktop
opens where you dropped it**, at the size of the window it came from, in any app whose tabs can be dragged out.

Nothing else changes: no tiling layout, no keyboard shortcut, no restyling. It acts only while you drag.

## How it compares

From each project's own documentation or source, checked on 2026-10-20. A dash means the source does not say.

| | Snaps to other windows | Snaps to screen edges | Animation | What else it does |
|---|---|---|---|---|
| **Window Magnet** (GNOME 50, 51) | yes, no key to hold | yes, also while resizing | spring | moves dropped tabs |
| GNOME 51, no extension | only while holding Ctrl | resists at screen and monitor edges; Shift makes it snap | none | drag to the top or a side to tile |
| [Tiling Assistant](https://extensions.gnome.org/extension/3733/tiling-assistant/), [Tiling Shell](https://extensions.gnome.org/extension/7065/tiling-shell/) | no: they fill screen regions and layouts | regions | — | tiling, snap assist, layouts |
| KDE Plasma (KWin) | yes, "window snap zone" | yes, "screen edge snap zone" | — | built into the desktop |
| Xfce (xfwm4) | yes, "Snap windows to other windows" | yes | — | built into the desktop |
| Windows Snap, [AquaSnap](https://www.nurgo-software.com/products/aquasnap) | Snap: no, it fills screen regions. AquaSnap's AquaMagnet: yes | yes | — | AquaSnap is a separate app |
| macOS [Magnet](https://magnet.crowdcafe.com/), [Rectangle](https://github.com/rxhanson/Rectangle) | not in their docs | dragging to an edge or corner fills a region | — | keyboard shortcuts |

Window Magnet and the tiling extensions have not been tested together: two extensions moving the same window during
a drag may fight.

## Install

### One command

```sh
curl -fsSL https://raw.githubusercontent.com/maximeallanic/window-magnet/main/install.sh | bash
```

The script downloads the release zip of the pinned version (0.1.0) from GitHub, checks its SHA-256 against the value
written in `install.sh`, installs it for your user with `gnome-extensions install` and enables it. No root, no build
tools. On Wayland, **log out and back in once** after the first install: GNOME Shell discovers new extensions at login.
The script is short and commented; read it first if you prefer. It works once the v0.1.0 release is published on
GitHub.

### From source

```sh
git clone https://github.com/maximeallanic/window-magnet.git
cd window-magnet
./install.sh --from-source       # needs gettext (msgfmt) to build the translations
```

### Manually, from the zip

1. Download `window-magnet@maximeallanic.github.io.shell-extension.zip` from the
   [latest release](https://github.com/maximeallanic/window-magnet/releases/latest)
   (and `SHA256SUMS` to check it: `sha256sum -c SHA256SUMS`).
2. Install it: `gnome-extensions install --force window-magnet@maximeallanic.github.io.shell-extension.zip`
3. Log out and back in, then: `gnome-extensions enable window-magnet@maximeallanic.github.io`

### From extensions.gnome.org

Not published yet. Once it is, you will be able to install it from the website or the *Extension Manager* app.

### Check that it works

```sh
curl -fsSL https://raw.githubusercontent.com/maximeallanic/window-magnet/main/verify.sh | bash
```

`verify.sh` changes nothing. It checks the GNOME Shell version, the installation, the settings schema, whether the
extension is enabled and running, and tells you what to do for anything that is not right.

### Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/maximeallanic/window-magnet/main/uninstall.sh | bash
# or, from a checkout: ./uninstall.sh [--purge]
```

The extension is disabled (no window stays offset), removed, and taken out of the enabled list. `--purge` also
resets its settings. The Extensions app's *Remove* button does the same, minus the settings.

## Settings

Open them with the Extensions app (*Window Magnet*, gear button) or `gnome-extensions prefs window-magnet@maximeallanic.github.io`.

![Preferences window: snap distance, snap to other windows, snap to screen edges, snap while resizing, spring
animation, open dropped tabs where they are dropped](media/prefs-en.png)

| Setting | Key | Default |
|---------|-----|---------|
| Snap distance: how close an edge must come before it snaps, 4 to 64 px | `snap-threshold` | `16` |
| Snap to other windows | `snap-to-windows` | on |
| Snap to screen edges | `snap-to-screen-edges` | on |
| Snap while resizing | `snap-while-resizing` | on |
| Spring animation | `spring-animation` | on |
| Open dropped tabs where they are dropped | `place-dropped-tabs` | on |

From a terminal (the schema ships with the extension, hence `--schemadir`):

```sh
gsettings --schemadir ~/.local/share/gnome-shell/extensions/window-magnet@maximeallanic.github.io/schemas \
    set org.gnome.shell.extensions.window-magnet snap-threshold 24
```

## Compatibility

| GNOME Shell | Status |
|-------------|--------|
| 51 | Supported, tested (Debian testing, Wayland) |
| 50 | Supported, tested (nested GNOME Shell 50.5 from Debian testing) |
| 49 and older | Not declared: GNOME will not load it |

- **Version 0.1.0, first release**: covered by unit tests and by an end-to-end run in a nested GNOME Shell (50 and 51)
  that drags real windows; not yet tried on many machines. Other distributions running GNOME Shell 50 or 51 should
  work, and reports are welcome.
- **Not on extensions.gnome.org yet** ([checklist](docs/extensions-gnome-org.md)).
- **Pointer and touch drags only**: keyboard moves (Alt+F7) do not snap.
- **Translations**: English and French so far. The preferences follow your desktop language through gettext; adding
  a language takes one `.po` file ([CONTRIBUTING.md](CONTRIBUTING.md)).
- Window Magnet uses only public GNOME Shell and Mutter APIs. A newer Shell is added to the list once it has been
  tested.

## FAQ

**Didn't GNOME drop window snapping on purpose?** It made it opt-in with Ctrl, because snapping to every nearby edge
made drags look jerky. Window Magnet animates the snap instead of jumping, and only pulls on edges that face each
other. If you prefer GNOME's behaviour, turn off *Snap to other windows* and keep the screen edges, or disable the
extension.

**Is it a tiling extension?** No. It never picks a size or a place for you; it finishes the alignment you started.
GNOME's own edge tiling (drag to the top to maximize, to a side for half the screen) is left as it is.

**I installed it but nothing happens.** On Wayland, log out and back in once after installing. Then run `verify.sh`
(above): it says what is missing.

**The window snaps but there is no spring.** The spring follows GNOME's animation setting: Settings, Accessibility,
Seeing, *Reduce Animation* must be off. Also check the *Spring animation* switch.

**Can I move a window without snapping?** Move it further than the snap distance and it follows the pointer exactly.
A smaller snap distance makes snaps rarer; *Snap to other windows* and *Snap to screen edges* turn each source off.

**Does it work with tiling extensions?** Not tested. Other extensions that also move windows during a drag may fight
with it; please report such cases.

**Multiple monitors?** Snapping uses the windows and the work area of the monitor the window is on.

**Which tabs does "dropped tabs" work with?** Any app whose tabs can be dragged out into a new window under Wayland
(libadwaita tab bars, for example). Nothing is app-specific: the extension recognises the drag Mutter shows and the
window the same app creates right after. If the tab is dropped into another window, nothing moves.

**Does it collect anything or talk to the network?** No. It spawns no process, opens no connection and reads no file.

**Is it related to Magnet for macOS?** No. Window Magnet is an independent GNOME project, not affiliated with the
makers of Magnet, Rectangle, AquaSnap or any other tool named on this page.

## How it works

See [docs/how-it-works.md](docs/how-it-works.md). Development, tests and media regeneration:
[docs/development.md](docs/development.md).

## Try it and tell us

Running GNOME Shell 50 or 51? Install it, drag a few windows around, and
[open an issue](https://github.com/maximeallanic/window-magnet/issues) with what felt right and what did not: your
distribution, your apps and your monitors are what the tests cannot cover. Translations are welcome too. Read
[CONTRIBUTING.md](CONTRIBUTING.md) and the [code of conduct](CODE_OF_CONDUCT.md). Security issues:
[SECURITY.md](SECURITY.md).

## Credits and licence

MIT, see [LICENSE](LICENSE). The spring comes from the motion toolkit of
[m3e-gnome-extensions](https://github.com/maximeallanic/m3e-gnome-extensions) (MIT, vendored unmodified), whose spring
solver is a port of Jetpack Compose's (Apache-2.0). Details in [NOTICE.md](NOTICE.md). Product names in the
comparison belong to their owners and only describe those products.
