# GitHub metadata, name check

Prepared for the owner before publication. Nothing here has been applied to GitHub, and the repository, the
extension's `name` and its UUID are unchanged. Research date: 2026-10-20.

## Pitch line

> Window edges that snap together, with a spring.

French: « Des bords de fenêtres qui s'aimantent, avec un ressort. »

Longer, for places with room for a second sentence: "Drag a window near another one and it lands flush; keep
pulling and it lets go. For GNOME Shell 51."

## Description (About, 350 characters max)

> GNOME Shell extension: while you move or resize a window, its edges snap to the other windows and to the screen
> edges, with a short spring and no key to hold. Pull further and it lets go. Tabs dropped on the desktop open where
> you drop them. A switch for each source; no tiling, no shortcuts. GNOME Shell 51.

308 characters. Website field: leave empty until there is an extensions.gnome.org page, then put that link.

## Topics (12)

`gnome`, `gnome-shell`, `gnome-shell-extension`, `gnome-extension`, `window-management`, `window-snapping`,
`edge-snapping`, `mutter`, `wayland`, `linux`, `linux-desktop`, `gjs`

Why these: the four `gnome*` topics are where GNOME extensions are browsed on GitHub; `window-management` and
`window-snapping` are what people search for; `edge-snapping` is the precise feature; `mutter`, `wayland` and `gjs`
say how it is built; `linux` and `linux-desktop` are the wide nets. Left out: `snap` (on GitHub it mostly means
Snapcraft packages), `tiling` and `tiling-window-manager` (it does not tile, and a topic reads as a claim),
`aero-snap` and `magnet` (other vendors' product names), `x11` (only Wayland has been tested).

## Social preview

Upload [social-preview.png](social-preview.png) (1280×640) in **Settings > General > Social preview**. It shows the
real capture `media/demo-poster.png` (three windows edge to edge in a nested GNOME Shell 51), cropped and scaled, with
the pitch line. The text does not contain the extension's name, so it survives a rename. At 320 px wide (the size of a
link card in a feed) the headline and the second line stay readable; the bottom line (GNOME 51, MIT) is small but
legible.

librsvg only loads images inside the SVG's folder, so render from a scratch copy:

```sh
s=~/.cache/claude-scratch/window-magnet-preview && mkdir -p "$s/media" && cp media/demo-poster.png "$s/media/"
sed 's#\.\./\.\./media/#media/#g' docs/marketing/social-preview.svg > "$s/social-preview.svg"
rsvg-convert -w 1280 -h 640 "$s/social-preview.svg" -o docs/marketing/social-preview.png
rm -r ~/.cache/claude-scratch/window-magnet-preview
```

## Name check

**Recommendation: keep "Window Magnet".** It says what the extension does in two plain words, nothing on
extensions.gnome.org, Flathub or Debian uses it, and the UUID, the GSettings schema, the gettext domain and the
repository slug are all built on it. The one real overlap, with the macOS app Magnet, is manageable (see below).

What a search found on 2026-10-20:

- **extensions.gnome.org**: searches for "window magnet", "magnet" and "magnetic" return no extension with that name.
  The "magnet" results are magnifier extensions and
  [Rectangle](https://extensions.gnome.org/extension/6553/rectangle/), described as "Magnet/Rectangle like manual
  tiling". The review guidelines ask that a name "should not conflict with another extension if possible": no
  conflict.
- **Flathub**: no app named Magnet or Window Magnet; "magnet" returns BitTorrent clients (magnet links).
- **Debian**: no package with "magnet" in its name that is related to windows.
- **GitHub**: five small repositories use the name, none for GNOME: `voidksa/WindowMagnet` (Windows, 2 stars),
  `NathanL15/WindowMagnet` (Windows), `johnmknight/WindowMagnet` (Windows, a window picker), `vanarman/windowMagnet`
  (2017), `Sammy970/window-magnet-poetry` (macOS joke app). None blocks the name.
- **The macOS app Magnet** (CrowdCafé, sold on the Mac App Store by BOOTCODE A.S., $4.99 on 2026-10-20) is the
  closest neighbour. Its App Store title is just "Magnet", but its bundle identifier is `com.crowdcafe.windowmagnet`
  and heise's download page lists it as "Window Magnet 3.0.7". So a web search for "window magnet" will show the Mac
  app first for a while.
- **Trademarks**: a web search found US registrations for MAGNET on unrelated software (surveying, digital evidence);
  none found for CrowdCafé or BOOTCODE. This is not a legal clearance.

Why keeping is still the better choice:

1. Different platform, different feature. Magnet snaps windows into screen regions on macOS; Window Magnet snaps
   window edges to each other on GNOME. Nobody installs a GNOME Shell extension expecting the Mac app.
2. People find GNOME extensions through extensions.gnome.org, the Extension Manager app and GitHub topics, where the
   name is free. The words "GNOME" and "window snapping" in the description do the rest.
3. A rename touches `metadata.json`, the UUID (users would have to reinstall), the schema id, the gettext domain, the
   scripts and both READMEs.

What to keep doing so the overlap stays harmless: always write "Window Magnet for GNOME" or "a GNOME Shell extension"
next to the name in posts; never use Magnet's icon, colours or wording; keep the non-affiliation line in the README
FAQ. Suggested wording elsewhere:

> Independent GNOME project, not affiliated with the makers of Magnet for macOS.

### Alternatives considered, not recommended

Checked on extensions.gnome.org and GitHub on 2026-10-20; not trademark clearance.

| Name | For | Against |
|---|---|---|
| Magnetic Edges | Precise, no app with that name found on extensions.gnome.org or GitHub | Loses "window" in search; two adjectives, less memorable |
| Edge Magnet | Short, says "edges" | Still "magnet"; nothing gained against the Mac app |
| Snap Together | Plain English, says the use | Generic; "snap" is crowded on GNOME (Snapcraft extensions) |
| Flush | One word, the result you get | Opaque without context; hard to search |
