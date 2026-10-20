# Security policy

## Reporting a vulnerability

Please report security issues **privately** through GitHub: *Security* tab, *Report a vulnerability*. Do not open a
public issue. Include the Window Magnet version, your GNOME Shell version and what an attacker can do. You will get an
answer within a week.

## Scope

GNOME Shell extensions run inside the Shell process with its full privileges. Window Magnet spawns no subprocess,
opens no network connection, reads and writes no file, and only uses its own GSettings schema. Reports about code in
this repository that breaks one of those properties, or that lets a window or an application crash or hijack the
Shell through it, are in scope. The install scripts are in scope too: `install.sh` downloads one pinned file over HTTPS
and checks its SHA-256 before installing it.

Vulnerabilities in GNOME Shell or Mutter themselves belong to those projects.

## Supported versions

Only the latest release.
