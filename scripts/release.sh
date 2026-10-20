#!/usr/bin/env bash
# Prepare a release, or check that the sources are ready for one.
#
#   scripts/release.sh VERSION         set VERSION everywhere, pack the zip and pin its SHA-256 in install.sh
#   scripts/release.sh --ci VERSION    change nothing: fail unless every version field says VERSION and the zip packed
#                                      here has exactly the SHA-256 pinned in install.sh (used by the release workflow)
#
# The zip is byte-for-byte reproducible (scripts/normalize-zip.py), which is what lets `curl ... install.sh | bash`
# trust a checksum written before the release exists. After `scripts/release.sh X.Y.Z`: update CHANGELOG.md, commit,
# tag vX.Y.Z on main and push the tag; the release workflow rebuilds the zip, checks it against the pin and publishes it.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UUID=window-magnet@maximeallanic.github.io
ci=0
[[ "${1:-}" == --ci ]] && { ci=1; shift; }
version="${1:-}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] || { echo "usage: release.sh [--ci] X.Y.Z" >&2; exit 2; }

meta_version() { python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get("version-name", ""))' "$1"; }
pinned() { sed -n "s/^$1=//p" "$ROOT/install.sh"; }

if [[ $ci -eq 0 ]]; then
    python3 - "$ROOT/extension/metadata.json" "$version" <<'PY'
import json, sys
path, version = sys.argv[1:]
meta = json.load(open(path, encoding="utf-8"))
meta["version-name"] = version
open(path, "w", encoding="utf-8").write(json.dumps(meta, indent=2, ensure_ascii=False) + "\n")
PY
    python3 - "$ROOT/package.json" "$version" <<'PY'
import json, sys
path, version = sys.argv[1:]
pkg = json.load(open(path, encoding="utf-8"))
pkg["version"] = version
open(path, "w", encoding="utf-8").write(json.dumps(pkg, indent=2, ensure_ascii=False) + "\n")
PY
    sed -i "s/^VERSION=.*/VERSION=$version/" "$ROOT/install.sh"
fi

errors=0
check() { [[ "$2" == "$version" ]] || { echo "error: $1 says '$2', expected '$version'" >&2; errors=1; }; }
check "extension/metadata.json version-name" "$(meta_version "$ROOT/extension/metadata.json")"
check "package.json version" "$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["version"])' "$ROOT/package.json")"
check "install.sh VERSION" "$(pinned VERSION)"
[[ $errors -eq 0 ]] || exit 1

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
"$ROOT/scripts/pack.sh" --out "$work" >/dev/null
sha="$(sha256sum "$work/$UUID.shell-extension.zip" | cut -d' ' -f1)"
if [[ $ci -eq 1 ]]; then
    [[ "$(pinned ZIP_SHA256)" == "$sha" ]] || {
        echo "error: the zip packed here has SHA-256 $sha but install.sh pins '$(pinned ZIP_SHA256)'" >&2
        echo "       run scripts/release.sh $version on a machine with the same toolchain and commit the result" >&2
        exit 1
    }
    echo "release $version: versions match, zip SHA-256 $sha matches the pin"
else
    sed -i "s/^ZIP_SHA256=.*/ZIP_SHA256=$sha/" "$ROOT/install.sh"
    echo "release $version prepared: zip SHA-256 $sha pinned in install.sh"
    echo "next: update CHANGELOG.md, commit, then: git tag v$version && git push origin v$version"
fi
