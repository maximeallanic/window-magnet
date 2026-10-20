# How Window Magnet works

Window Magnet only acts while you move or resize a window with the pointer (mouse, touchpad or touch). It never
changes corners, shadows or the Shell's own animations, and it does nothing to windows you do not touch.

## Moving

- On `grab-op-begin` with a move operation, the extension listens to `position-changed` (and `size-changed`) of the
  window being moved.
- On every motion, `snap.js` (pure maths, no GNOME dependency, unit-tested headless) compares both edges of each axis
  of the window with the candidate lines: the edges of the other normal windows that are visible on the same
  workspace and monitor, and the edges of the monitor's work area (the screen minus the top bar and docks).
  Another window only counts on one axis when it overlaps the moved window on the other axis (within the threshold),
  so a window far above does not pull a vertical edge.
- The smallest correction within the threshold (16 px by default) wins, independently on each axis.
- Mutter recomputes the raw position from the pointer at every motion, so a snap naturally *holds* the window until
  the pointer has moved further than the threshold; then the window jumps back under the pointer.

## The spring

A snap is a jump of the window's real position. `springBack.js` offsets the window's actor by the opposite of the
jump and lets a spring bring that offset back to zero (the Material 3 Expressive "FastSpatial" spring of the vendored
motion toolkit, `extension/m3e/`). Only the actor's translation is animated; the window's real position, as other
windows and apps see it, is snapped at once. A new jump starts from the current offset and velocity, so quick
back-and-forth moves stay continuous.

The toolkit follows GNOME's *Reduce Animation* setting (`org.gnome.desktop.interface enable-animations`) and the
Shell's slow-down factor: with animations off, the offset is written at its target at once and the window simply
jumps.

## Resizing

Only the edges you drag snap (`snapResize`), with the same threshold, live during the gesture. The rect aimed at is
computed like Mutter does it (initial rect plus pointer travel, `resizedRect`), not from the size the client has
committed.

Mutter computes the raw size in a `BEFORE_REDRAW` *later*, run on the stage's `before-update` signal. The extension
connects to the same signal after Mutter, so the snapped size (`move_resize_frame`) leaves in the same frame as the
raw one and the Wayland client only applies the last configure. Correcting on `size-changed` instead (after the
client's commit) made the window alternate between both sizes. The clean API, `Meta.ExternalConstraint`, cannot be
used from GJS. A last correction is applied on `grab-op-end`.

## Tabs dropped on the desktop

On Wayland an app cannot place its own windows, so a tab dragged out of a window and dropped on the desktop opens
wherever Mutter decides, at the app's default size. `dropPlacer.js` (pure maths in `drop.js`) fixes that without
naming any app:

- Mutter shows a drag as a `MetaDnDActor` in its feedback group (`global.compositor.get_feedback_group()`); the actor
  knows the surface the drag started from. A normal window created by the same process within 500 ms after that actor
  goes away is the detached tab (measured: 30 to 130 ms). A tab dropped into another window creates nothing, so
  nothing moves.
- Position: the window's top-left corner goes where the top-left corner of the dragged preview was at the drop,
  kept inside the work area of the monitor under the pointer.
- Size: the size of the window the tab came from, reduced to the work area if needed. If that window was maximized
  or full screen, the app's default size is kept. Mutter does not expose half-screen tiling to GJS: a tab from a
  half-screen window opens floating at the same size.
- Timing (measured on Mutter 51): the size is requested at `window-created`, so it travels in the first configure and
  the first frame is already right; the position is applied at `shown`, because Mutter's own placement runs just
  before and overrides anything sent earlier.

The behaviour can be turned off with the *Open dropped tabs where they are dropped* switch (`place-dropped-tabs`).

## Clean-up

`disable()` disconnects every signal, stops every spring and puts every actor offset it created back to zero, and
destroys the tab placer (its timeouts included). The end-to-end test disables the extension in the middle of a drag
and checks that no window stays offset (`dev/nested/scenes.py`, step 6).

## Files

```
extension/
  extension.js     wiring to Mutter: grab begin/end, move and resize snapping, settings
  snap.js          snapping maths (unit-tested)
  jump.js          the jump a snap makes, fed to the spring (unit-tested)
  springBack.js    actor offset on a spring
  drop.js          tab drop geometry and matching (unit-tested)
  dropPlacer.js    tab drop detection and placement
  prefs.js         preferences window (GTK 4 / libadwaita)
  m3e/             vendored motion toolkit (see NOTICE.md and vendor/m3e.lock)
  schemas/         GSettings schema
```
