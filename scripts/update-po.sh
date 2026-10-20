#!/usr/bin/env bash
# Regenerate po/window-magnet.pot from the sources and merge it into every po/*.po, or check that they are current.
#
#   scripts/update-po.sh            rewrite the template and merge the catalogues (then translate what is new)
#   scripts/update-po.sh --check    exit 1 if the template is stale or a catalogue has untranslated or fuzzy messages
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POT="$ROOT/po/window-magnet.pot"
for tool in xgettext msgmerge msgfmt; do
    command -v "$tool" >/dev/null || { echo "$tool is required (package gettext)" >&2; exit 2; }
done
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT

(cd "$ROOT" && xgettext --from-code=UTF-8 --language=JavaScript --keyword=_ --keyword=ngettext:1,2 --add-comments=Translators \
    --package-name=window-magnet --msgid-bugs-address=https://github.com/maximeallanic/window-magnet/issues \
    --copyright-holder="Maxime Allanic" --sort-by-file -o "$work/new.pot" extension/*.js)
# Only the messages matter (everything after the header entry): the header carries the date of each run.
messages() { awk 'body; /^$/ { body = 1 }' "$1"; }

if [[ "${1:-}" == --check ]]; then
    status=0
    if ! diff -q <(messages "$POT") <(messages "$work/new.pot") >/dev/null; then
        echo "po/window-magnet.pot is stale: run scripts/update-po.sh" >&2
        diff <(messages "$POT") <(messages "$work/new.pot") >&2 || true
        status=1
    fi
    for po in "$ROOT"/po/*.po; do
        stats="$(LC_ALL=C msgfmt --check --statistics -o /dev/null "$po" 2>&1)" || { echo "$po: $stats" >&2; status=1; continue; }
        if [[ "$stats" == *untranslated* || "$stats" == *fuzzy* ]]; then
            echo "$(basename "$po"): $stats" >&2; status=1
        fi
        msgmerge --quiet --no-fuzzy-matching -o "$work/merged.po" "$po" "$POT"
        [[ "$(LC_ALL=C msgfmt --statistics -o /dev/null "$work/merged.po" 2>&1)" == "$stats" ]] ||
            { echo "$(basename "$po") is not merged with the template: run scripts/update-po.sh" >&2; status=1; }
    done
    [[ $status -eq 0 ]] && echo "translations are up to date"
    exit $status
fi

if ! diff -q <(messages "$POT") <(messages "$work/new.pot") >/dev/null; then
    { awk '{ print } /^$/ { exit }' "$POT"; messages "$work/new.pot"; } >"$work/merged.pot"
    sed -i "s/^\"POT-Creation-Date: .*/\"POT-Creation-Date: $(date -u '+%Y-%m-%d %H:%M+0000')\\\\n\"/" "$work/merged.pot"
    cp "$work/merged.pot" "$POT"
fi
for po in "$ROOT"/po/*.po; do
    msgmerge --quiet --update --backup=none --no-fuzzy-matching "$po" "$POT"
    LC_ALL=C msgfmt --check --statistics -o /dev/null "$po"
done
