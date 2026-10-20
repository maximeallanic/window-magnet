# Development

## Layout

```
extension/          the extension, exactly what goes in the zip (see docs/how-it-works.md)
po/                 translation template and catalogues (gettext domain window-magnet)
scripts/            pack.sh, check-zip.py, normalize-zip.py, release.sh, release-notes.sh, update-po.sh, update-m3e.sh
tests/              run.sh (all headless checks), unit/ (gjs), test_install.sh and its shims
dev/nested/         end-to-end test and media capture in an isolated, headless GNOME Shell
vendor/m3e.lock     origin and checksums of the vendored motion toolkit
media/              README media, all captured from the nested Shell
install.sh, verify.sh, uninstall.sh
```

## Requirements

GNOME Shell 50 or 51 with `gjs` and `gnome-extensions`, `gettext`, `python3`. Optional: `shellcheck`, Node.js 20+ for ESLint
(`npm ci`), `python3-dbusmock` and `ffmpeg` for `dev/nested/`. On Debian testing:

```sh
sudo apt install gjs gnome-shell gettext python3 shellcheck python3-dbusmock ffmpeg nodejs npm
```

## Headless checks

```sh
npm ci            # once, for ESLint
tests/run.sh
```

`tests/run.sh` runs the unit tests (`gjs -m tests/unit/test_*.js`), checks that the translations are up to date and
complete, that `extension/m3e/` matches `vendor/m3e.lock`, packs and checks the zip, runs `tests/test_install.sh`
(install, verify, reinstall and uninstall against a throw-away `HOME` with fake `gsettings` and `gnome-shell`), then
ShellCheck and ESLint when they are installed. CI runs the same script in a `debian:testing` container.

## End-to-end test in a nested GNOME Shell

```sh
dev/nested/nested.sh --scenario e2e --out /some/dir
```

This starts `gnome-shell --headless --virtual-monitor 1280x720` with a private `HOME`, XDG directories, session bus,
system bus (a fake logind from python-dbusmock) and dconf database, installs the zip built by `scripts/pack.sh` with
`gnome-extensions install`, and loads a test-only driver extension (`dev/nested/driver@window-magnet.test/`) that
exposes virtual pointer and keyboard devices over D-Bus. `dev/nested/scenes.py` then opens plain GTK windows and checks:
snapping to a window while held and after release, top edges aligned, spring offset back to zero, release beyond the
threshold, screen edge, each setting, live resize snapping, and disable in the middle of a drag followed by enable.
Nothing of your session is touched: the script refuses to run if the environment is not private and exits with code 3
if your real dconf database changed during the run.

Run heavy jobs in their own memory-limited scope if your machine is busy, for example
`systemd-run --user --scope -p MemoryHigh=4G -p MemoryMax=6G dev/nested/nested.sh ...`.

The same run works for another GNOME Shell major inside a container: that is how GNOME Shell 50 (Debian testing,
50.5) is tested from a GNOME 51 machine. Build an image from `debian:testing` with `gnome-shell
gnome-shell-extension-prefs dbus-daemon dconf-cli dconf-service python3-gi python3-dbusmock gir1.2-gtk-4.0
libgl1-mesa-dri` (the Shell renders with llvmpipe, no GPU needed), pack the zip on the host, then:

```sh
scripts/pack.sh --out "$s/zip"
docker run --rm -v "$PWD:/repo:ro" -v "$s:/s" IMAGE bash -c 'mkdir -m700 -p /tmp/xdg &&
    XDG_RUNTIME_DIR=/tmp/xdg /repo/dev/nested/nested.sh --scenario e2e --out /s/e2e \
    --zip /s/zip/window-magnet@maximeallanic.github.io.shell-extension.zip'
```

## Regenerating the media

```sh
dev/nested/nested.sh --scenario demo --out /tmp/wm-demo
WM_PREFS_LANG=C.UTF-8 dev/nested/nested.sh --scenario prefs --size 1100x900 --out /tmp/wm-prefs-en
WM_PREFS_LANG=fr_FR.UTF-8 dev/nested/nested.sh --scenario prefs --size 1100x900 --out /tmp/wm-prefs-fr
dev/nested/make-media.sh --demo /tmp/wm-demo --prefs /tmp/wm-prefs-en --prefs /tmp/wm-prefs-fr
```

The demo is recorded with the Shell's own screencast (`org.gnome.Shell.Screencast`, through your PipeWire) while the
Shell runs three times slower, so that a loaded machine still renders every frame; `make-media.sh` divides the
timestamps by the same factor. No frame is drawn or edited. The preferences captures need the `fr_FR.UTF-8` locale for
the French one.

## Translations

```sh
scripts/update-po.sh            # after changing a user-visible string
```

Then translate the new entries in `po/<lang>.po`. A new language is a new `po/<lang>.po` (`msginit -l <lang>
-i po/window-magnet.pot -o po/<lang>.po`); `scripts/pack.sh` compiles every catalogue it finds.

## Vendored motion toolkit

`extension/m3e/` is copied, unmodified, from `shared/m3e/` of
[m3e-gnome-extensions](https://github.com/maximeallanic/m3e-gnome-extensions). To update it:

```sh
scripts/update-m3e.sh /path/to/m3e-gnome-extensions    # copies the files and rewrites vendor/m3e.lock
```

Never edit the copy by hand: `scripts/update-m3e.sh --check` (part of `tests/run.sh`) fails on any difference.

## Releasing

```sh
scripts/release.sh 0.2.0     # version in metadata.json (version-name), package.json, install.sh; pins the zip SHA-256
# add the 0.2.0 section to CHANGELOG.md, commit
git tag v0.2.0 && git push origin main v0.2.0
```

The zip is reproducible, so `install.sh` can pin its checksum before the release exists. The release workflow
rebuilds the zip in `debian:testing`, fails if its SHA-256 differs from the pin (`scripts/release.sh --ci`), and
publishes the GitHub release with the zip and `SHA256SUMS`. Run `scripts/release.sh` with the same toolchain
(Debian testing, or the same `gettext` version): `msgfmt` output is part of the zip. Then upload the same zip to
extensions.gnome.org (see [extensions-gnome-org.md](extensions-gnome-org.md)).
