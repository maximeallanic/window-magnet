#!/usr/bin/env bash
# Every check that needs no display: unit tests (gjs), translations, vendored toolkit, the extensions.gnome.org zip,
# the install / verify / uninstall scripts (sandboxed), ShellCheck and ESLint when they are installed.
# The end-to-end run in a nested GNOME Shell is separate: dev/nested/nested.sh --scenario e2e --out DIR.
#
#   tests/run.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
failed=()
step() {
    local name="$1"; shift
    printf '== %s\n' "$name"
    if "$@"; then printf '   ok\n'; else printf '   FAILED\n'; failed+=("$name"); fi
}
skip() { printf '== %s\n   skipped: %s\n' "$1" "$2"; }

for t in tests/unit/test_*.js; do
    step "unit: $(basename "$t" .js)" gjs -m "$t"
done
step "translations up to date" scripts/update-po.sh --check
step "vendored toolkit matches vendor/m3e.lock" scripts/update-m3e.sh --check
pack_dir="$(mktemp -d)"
trap 'rm -rf -- "$pack_dir"' EXIT
step "zip for extensions.gnome.org" scripts/pack.sh --out "$pack_dir"
step "install / verify / uninstall (sandbox)" tests/test_install.sh
if command -v shellcheck >/dev/null; then
    mapfile -t scripts < <(find . -xdev -path ./node_modules -prune -o -type f \( -name '*.sh' -o -path './tests/shims/*' \) -print)
    step "shellcheck" shellcheck -x "${scripts[@]}"
else
    skip shellcheck "shellcheck is not installed"
fi
if [[ -x node_modules/.bin/eslint ]]; then
    step "eslint" node_modules/.bin/eslint .
else
    skip eslint "run npm ci first"
fi

if [[ ${#failed[@]} -gt 0 ]]; then
    printf '\n%d check(s) failed: %s\n' "${#failed[@]}" "${failed[*]}"
    exit 1
fi
printf '\nall checks passed\n'
