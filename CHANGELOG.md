# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-10-20

First public release.

### Added

- Edge snapping while moving a window: both edges of each axis snap to the edges of the other windows on the same
  workspace and monitor, and to the edges of the monitor's work area.
- Edge snapping while resizing: the edges you drag snap, live, in the same frame as Mutter's own resize.
- A spring (Material 3 Expressive "FastSpatial") that smooths the jump of each snap; it follows GNOME's
  *Reduce Animation* setting.
- Tabs dragged out of an app window and dropped on the desktop open their window where they were dropped, at the size
  of the window they came from.
- Preferences: snap distance (4 to 64 px, default 16), snap to windows, snap to screen edges, snap while resizing,
  spring animation, dropped-tab placement.
- Translations: French.
- `install.sh` (one-line install of the pinned release zip, checksum verified), `verify.sh`, `uninstall.sh`.
- Zip for extensions.gnome.org built and checked by `scripts/pack.sh`.

[Unreleased]: https://github.com/maximeallanic/window-magnet/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/maximeallanic/window-magnet/releases/tag/v0.1.0
