#!/usr/bin/env python3
"""Check the zip produced by scripts/pack.sh before it is uploaded to extensions.gnome.org or attached to a release.

Checks: metadata.json is valid, its uuid matches the file name, the keys extensions.gnome.org reviews are present and
sane (shell-version non-empty and stable majors only, url, settings-schema, gettext-domain, no "version" key, no
"session-modes" that only lists "user"); extension.js and prefs.js are present; the schema XML is shipped and named
after its id, the compiled schema is not; every relative ES import resolves inside the zip; no Gtk/Gdk/Adw import in the
Shell process and no Clutter/Meta/St/Shell/Mtk import in prefs.js; no deprecated module (Lang, Mainloop, ByteArray); no
build leftovers, scripts, binaries, .po/.pot files, or source files over 500 lines (the generated m3e/tokens.js
excepted); at least one compiled translation catalogue.

Usage: check-zip.py ZIP
"""
import json
import re
import sys
import zipfile
from pathlib import PurePosixPath

IMPORT_RE = re.compile(r"""^\s*(?:import|export)\s[^;'"]*?from\s*['"]([^'"]+)['"]|^\s*import\s*['"]([^'"]+)['"]""", re.M)
SHELL_ONLY = {"gi://Clutter", "gi://Meta", "gi://St", "gi://Shell", "gi://Mtk"}
PREFS_ONLY = {"gi://Gtk", "gi://Gdk", "gi://Adw"}
DEPRECATED = re.compile(r"imports\.(?:lang|mainloop|byteArray)\b")
FORBIDDEN_SUFFIXES = (".pyc", ".orig", ".rej", ".swp", "~", ".so", ".o", ".po", ".pot", ".sh", ".py", ".md", ".mp4", ".gif")
FORBIDDEN_PARTS = {"__pycache__", ".git", "node_modules", "tests"}
GENERATED = {"m3e/tokens.js"}
LINE_LIMIT = 500


def resolve(base, target):
    parts = []
    for part in PurePosixPath(*base.parts, *PurePosixPath(target).parts).parts:
        if part == "..":
            if parts:
                parts.pop()
        elif part != ".":
            parts.append(part)
    return "/".join(parts)


def check_metadata(meta, file_name):
    errors = []
    expected = file_name.removesuffix(".shell-extension.zip")
    if meta.get("uuid") != expected:
        errors.append(f"uuid {meta.get('uuid')!r} does not match file name {expected!r}")
    for key in ("name", "description", "shell-version", "url", "settings-schema", "gettext-domain"):
        if not meta.get(key):
            errors.append(f"metadata.json: {key} missing or empty")
    if "version" in meta:
        errors.append("metadata.json: 'version' is set by extensions.gnome.org, remove it")
    if meta.get("session-modes") == ["user"]:
        errors.append("metadata.json: drop session-modes when it only lists 'user'")
    for v in meta.get("shell-version", []):
        if not re.fullmatch(r"[0-9]{2,}", v):
            errors.append(f"metadata.json: shell-version {v!r} is not a stable major version")
    return errors


def check_source(name, source, names):
    errors = []
    if source.count("\n") + 1 > LINE_LIMIT and name not in GENERATED:
        errors.append(f"{name}: more than {LINE_LIMIT} lines")
    if DEPRECATED.search(source):
        errors.append(f"{name}: deprecated module (Lang, Mainloop or ByteArray)")
    base = PurePosixPath(name).parent
    for match in IMPORT_RE.finditer(source):
        target = match.group(1) or match.group(2)
        if name == "prefs.js" and target in SHELL_ONLY:
            errors.append(f"prefs.js imports {target} (Shell-process library)")
        if name != "prefs.js" and target in PREFS_ONLY:
            errors.append(f"{name} imports {target} (GTK in the Shell process)")
        if target.startswith(".") and resolve(base, target) not in names:
            errors.append(f"{name}: import {target!r} does not resolve inside the zip")
    return errors


def check(path):
    with zipfile.ZipFile(path) as z:
        names = set(z.namelist())
        errors = ["corrupt zip"] if z.testzip() is not None else []
        if "metadata.json" not in names:
            return errors + ["metadata.json missing"]
        meta = json.loads(z.read("metadata.json"))
        errors += check_metadata(meta, PurePosixPath(path).name)
        for required in ("extension.js", "prefs.js", f"schemas/{meta.get('settings-schema')}.gschema.xml"):
            if required not in names:
                errors.append(f"{required} missing")
        if "schemas/gschemas.compiled" in names:
            errors.append("schemas/gschemas.compiled shipped (GNOME 44+ compiles schemas at install time)")
        domain = meta.get("gettext-domain")
        if not any(n.startswith("locale/") and n.endswith(f"/LC_MESSAGES/{domain}.mo") for n in names):
            errors.append(f"no compiled translation locale/*/LC_MESSAGES/{domain}.mo")
        for name in sorted(names):
            if set(PurePosixPath(name).parts) & FORBIDDEN_PARTS or name.endswith(FORBIDDEN_SUFFIXES):
                errors.append(f"unwanted file in zip: {name}")
            if name.endswith(".js"):
                errors += check_source(name, z.read(name).decode("utf-8"), names)
    return errors


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    errors = check(sys.argv[1])
    print(f"{'FAIL' if errors else 'ok  '} {PurePosixPath(sys.argv[1]).name}")
    for e in errors:
        print(f"     {e}")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
