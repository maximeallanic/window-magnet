# Contributing

Thanks for helping. Window Magnet runs inside GNOME Shell, so small, careful changes with a clean `disable()` are what
matter most.

## Ways to contribute

- **Report a bug** with the issue form. Include the output of `verify.sh`, your GNOME Shell version, distribution and
  session type, and the steps to reproduce.
- **Try it on another setup** (distribution, GNOME Shell version, multi-monitor, fractional scaling, apps whose tabs
  can be dragged out) and say what you saw.
- **Translate it**: add `po/<lang>.po` (see [docs/development.md](docs/development.md#translations)).
- **Fix something or add a feature**: open an issue first for anything beyond a small fix, so that nobody spends time
  on something that will not be merged.

## How to contribute code

1. Fork the repository and create a branch from `main` named `type/short-description` (`fix/...`, `feat/...`,
   `docs/...`).
2. Keep the change focused: one subject per pull request.
3. Run `tests/run.sh`; for a behaviour change, also the nested end-to-end test
   (`dev/nested/nested.sh --scenario e2e --out DIR`, see [docs/development.md](docs/development.md)). Add or update
   tests for what you changed: the maths live in pure modules (`snap.js`, `jump.js`, `drop.js`) on purpose.
4. Commit with [Conventional Commits](https://www.conventionalcommits.org/) messages in English
   (`fix(snap): ignore minimized windows`). The pull request title follows the same format.
5. Open the pull request against `main` and fill in the template.

By contributing you agree that your work is released under the MIT licence of the repository.

## Ground rules

- **English in code**: identifiers, comments, log lines. User-visible strings go through gettext (`_()`), and no
  language, locale or script is hard-coded anywhere.
- **`disable()` undoes everything `enable()` did**: signal connections, GLib sources, springs, actor offsets.
- **Fix causes, not symptoms**: no retry loop hiding a failure, no empty `catch`.
- Follow the [extensions.gnome.org review guidelines](https://gjs.guide/extensions/review-guidelines/review-guidelines.html)
  (see [docs/extensions-gnome-org.md](docs/extensions-gnome-org.md)).
- **Source files stay under 500 lines.** Split along a real seam, never at an arbitrary line.
- `extension/m3e/` is vendored: never edit it by hand (`scripts/update-m3e.sh`).
