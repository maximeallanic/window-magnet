#!/usr/bin/env python3
"""Demo windows for the nested Shell: plain GTK 4 windows with a coloured body and a big label, so that a recording shows
nothing but the windows themselves (no file names, no host data).

Usage: client.py TITLE=#RRGGBB [TITLE=#RRGGBB ...]   (run with WAYLAND_DISPLAY of the nested Shell)
"""
import sys

import gi

gi.require_version("Gdk", "4.0")
gi.require_version("Gtk", "4.0")
from gi.repository import Gdk, Gio, Gtk  # noqa: E402

CSS = """
window.demo-{i} {{ background: {color}; }}
window.demo-{i} headerbar {{ background: shade({color}, 0.88); box-shadow: none; }}
window.demo-{i} .big {{ font-size: 44px; font-weight: 600; color: rgba(0, 0, 0, 0.62); }}
"""


def build(app, specs):
    provider = Gtk.CssProvider()
    css = "".join(CSS.format(i=i, color=color) for i, (_title, color) in enumerate(specs))
    provider.load_from_string(css)
    Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), provider,
                                              Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    for i, (title, _color) in enumerate(specs):
        win = Gtk.ApplicationWindow(application=app, title=title, default_width=420, default_height=300)
        win.add_css_class(f"demo-{i}")
        bar = Gtk.HeaderBar()
        win.set_titlebar(bar)
        label = Gtk.Label(label=title)
        label.add_css_class("big")
        win.set_child(label)
        win.present()


def main():
    specs = [tuple(arg.split("=", 1)) for arg in sys.argv[1:]]
    if not specs or any(len(s) != 2 for s in specs):
        sys.exit(__doc__)
    # NON_UNIQUE: no bus name to register (and nothing to wait for on the private bus).
    app = Gtk.Application(application_id="io.github.maximeallanic.WindowMagnetDemo",
                          flags=Gio.ApplicationFlags.NON_UNIQUE)
    app.connect("activate", lambda a: build(a, specs))
    sys.exit(app.run([sys.argv[0]]))


if __name__ == "__main__":
    main()
