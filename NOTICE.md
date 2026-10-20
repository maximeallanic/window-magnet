# Third-party notices

Window Magnet is released under the MIT License (see `LICENSE`). The items below come from other projects and keep
their own licenses.

## M3E motion toolkit (MIT)

- Project: m3e-gnome-extensions, <https://github.com/maximeallanic/m3e-gnome-extensions>, commit
  `9f8f5f47866e619a876522a75a16146b721157bb`, directory `shared/m3e`.
- Vendored unmodified in `extension/m3e/` (`animate.js`, `track.js`, `spring.js`, `curve.js`, `tokens.js`); the
  SHA-256 of each file is recorded in `vendor/m3e.lock` and checked by `scripts/update-m3e.sh --check`.
- Copyright (c) 2026 Maxime Allanic. MIT License, the same as this repository.

## Jetpack Compose animation (Apache License 2.0)

- Project: AndroidX, <https://github.com/androidx/androidx>.
- Used for: the spring solver of `extension/m3e/spring.js` is a port of `SpringSimulation.kt` and
  `SpringEstimation.kt` (`compose/animation/animation-core`); the Material 3 Expressive motion token values in
  `extension/m3e/tokens.js` (spring stiffness and damping) come from Compose Material 3.
- Copyright 2024 The Android Open Source Project. Licensed under the Apache License, Version 2.0
  (<https://www.apache.org/licenses/LICENSE-2.0>).

## GNOME Shell (GPL-2.0-or-later)

Window Magnet runs inside GNOME Shell and uses its JavaScript modules and the Mutter, Clutter, GLib and GTK libraries
at run time; it does not copy their source. `dev/nested/nested.sh` (a development tool, not shipped in the zip) is
adapted from `tests/bench/nested.sh` of m3e-gnome-extensions (MIT, same author).
