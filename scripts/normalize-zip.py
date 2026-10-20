#!/usr/bin/env python3
"""Rewrite an extension zip in place so that the same sources always give the same bytes (the SHA-256 pinned in
install.sh can then be checked against a zip rebuilt by CI): entries sorted, fixed timestamp, fixed permissions,
directory entries dropped. Also drops schemas/gschemas.compiled: GNOME Shell 44 and later compile the schema at install
time and extensions.gnome.org reviewers ask for the XML only.

Usage: normalize-zip.py ZIP
"""
import sys
import zipfile

COMPILED = "schemas/gschemas.compiled"
EPOCH = (1980, 1, 1, 0, 0, 0)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    path = sys.argv[1]
    with zipfile.ZipFile(path) as z:
        entries = {i.filename: z.read(i) for i in z.infolist() if not i.is_dir() and i.filename != COMPILED}
    with zipfile.ZipFile(path, "w") as z:
        for name in sorted(entries):
            info = zipfile.ZipInfo(name, date_time=EPOCH)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3                      # Unix, so that the permissions below are honoured
            info.external_attr = 0o100644 << 16
            z.writestr(info, entries[name], compresslevel=9)


if __name__ == "__main__":
    main()
