// Test driver of dev/nested. Only enabled in the nested, headless GNOME Shell started by dev/nested/nested.sh; it
// exposes this API on the PRIVATE session bus of that Shell (name io.github.maximeallanic.WindowMagnetDriver):
//   Ping()                      -> 'pong' once the Shell has started up
//   Run(scenario)               -> starts `python3 $WM_NESTED_SCRIPTS/scenes.py <out> <scenario>` (returns at once)
//   Result(scenario)            -> '' while it runs, then JSON {ok, exit_code, scenario}
//   Windows()                   -> JSON [{id, title, x, y, w, h, tx, ty, type, pid}] (frame rect, actor translation, Meta.WindowType)
//   Place(id, x, y, w, h)       -> moves and resizes a window, then activates it
//   PointerPosition()           -> [x, y] of the pointer
//   ShellState()                -> JSON {overview, modalCount, actionMode, sessionMode, locked, focus}
//   HideOverview()              -> leaves the overview (shown at start-up)
//   Capture(path)               -> PNG of the whole virtual screen, pointer included
//   Pointer(x, y) / Glide(x, y, seconds) / Button(button, pressed) / Key(keyval, pressed)
//   SlowDown(factor)            -> St.Settings slow-down-factor of the nested Shell
//   SetSetting(key, json)       -> writes one Window Magnet setting (its schema, private dconf)
//   SetEnabled(enabled)         -> enables / disables Window Magnet through the extension manager
//   State()                     -> JSON {state, error} of Window Magnet as the extension manager sees it
//   HideRecordingIndicator()    -> hides the screencast indicator of the top bar
// The devices are virtual Clutter devices of the nested Shell: nothing reaches the real session.
import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Shell from 'gi://Shell';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const NAME = 'io.github.maximeallanic.WindowMagnetDriver';
const PATH = '/io/github/maximeallanic/WindowMagnetDriver';
const MAGNET = 'window-magnet@maximeallanic.github.io';
const SCENARIO = /^[a-z0-9-]+$/;
const now = () => GLib.get_monotonic_time();

const XML = `
<node>
  <interface name="${NAME}">
    <method name="Ping"><arg type="s" direction="out"/></method>
    <method name="Run"><arg type="s" direction="in" name="scenario"/></method>
    <method name="Result"><arg type="s" direction="in" name="scenario"/><arg type="s" direction="out"/></method>
    <method name="Windows"><arg type="s" direction="out"/></method>
    <method name="PointerPosition"><arg type="ad" direction="out"/></method>
    <method name="ShellState"><arg type="s" direction="out"/></method>
    <method name="HideOverview"/>
    <method name="Capture"><arg type="s" direction="in"/><arg type="s" direction="out"/></method>
    <method name="Place"><arg type="u" direction="in"/><arg type="i" direction="in"/><arg type="i" direction="in"/><arg type="i" direction="in"/><arg type="i" direction="in"/></method>
    <method name="Pointer"><arg type="d" direction="in"/><arg type="d" direction="in"/></method>
    <method name="Glide"><arg type="d" direction="in"/><arg type="d" direction="in"/><arg type="d" direction="in"/></method>
    <method name="Button"><arg type="u" direction="in"/><arg type="b" direction="in"/></method>
    <method name="Key"><arg type="u" direction="in"/><arg type="b" direction="in"/></method>
    <method name="SlowDown"><arg type="d" direction="in"/></method>
    <method name="SetSetting"><arg type="s" direction="in"/><arg type="s" direction="in"/></method>
    <method name="SetEnabled"><arg type="b" direction="in"/></method>
    <method name="State"><arg type="s" direction="out"/></method>
    <method name="HideRecordingIndicator"/>
  </interface>
</node>`;

export default class Driver extends Extension {
    enable() {
        this._runs = new Map();
        this._glide = 0;
        const seat = global.stage.context.get_backend().get_default_seat();
        this._pointer = seat.create_virtual_device(Clutter.InputDeviceType.POINTER_DEVICE);
        this._keyboard = seat.create_virtual_device(Clutter.InputDeviceType.KEYBOARD_DEVICE);
        this._exported = Gio.DBusExportedObject.wrapJSObject(XML, this);
        this._exported.export(Gio.DBus.session, PATH);
        const own = () => {
            Main.overview.hide();
            this._ownerId = Gio.bus_own_name_on_connection(Gio.DBus.session, NAME, Gio.BusNameOwnerFlags.NONE, null, null);
        };
        if (Main.layoutManager._startingUp)
            this._startupId = Main.layoutManager.connect('startup-complete', own);
        else
            own();
    }

    disable() {
        if (this._startupId)
            Main.layoutManager.disconnect(this._startupId);
        if (this._ownerId)
            Gio.bus_unown_name(this._ownerId);
        this._exported?.unexport();
        for (const run of this._runs.values())
            run.process.force_exit();
        if (this._glide)
            GLib.source_remove(this._glide);
        this._glide = 0;
        this._pointer = this._keyboard = this._exported = null;
    }

    Ping() {
        return 'pong';
    }

    Run(scenario) {
        const scripts = GLib.getenv('WM_NESTED_SCRIPTS');
        const out = GLib.getenv('WM_NESTED_OUT');
        if (!SCENARIO.test(scenario) || !scripts || !out)
            throw new Error(`Run ${scenario}: invalid scenario or WM_NESTED_SCRIPTS / WM_NESTED_OUT missing`);
        const launcher = new Gio.SubprocessLauncher({flags: Gio.SubprocessFlags.STDERR_MERGE});
        launcher.set_stdout_file_path(`${out}/scene-${scenario}.log`);
        launcher.setenv('WAYLAND_DISPLAY', GLib.getenv('WAYLAND_DISPLAY'), true);
        const process = launcher.spawnv(['python3', `${scripts}/scenes.py`, out, scenario]);
        const run = {process, result: null};
        this._runs.set(scenario, run);
        process.wait_async(null, (p, res) => {
            p.wait_finish(res);
            const code = p.get_if_exited() ? p.get_exit_status() : -1;
            run.result = JSON.stringify({ok: code === 0, exit_code: code, scenario});
        });
    }

    Result(scenario) {
        return this._runs.get(scenario)?.result ?? '';
    }

    _window(id) {
        const actor = global.get_window_actors().find(a => a.meta_window.get_id() === id);
        if (!actor)
            throw new Error(`no window ${id}`);
        return actor.meta_window;
    }

    Windows() {
        return JSON.stringify(global.get_window_actors()
            .map(a => {
                const w = a.meta_window;
                const r = w.get_frame_rect();
                return {id: w.get_id(), title: w.get_title() ?? '', x: r.x, y: r.y, w: r.width, h: r.height,
                    tx: a.translation_x, ty: a.translation_y, type: w.get_window_type(),
                    pid: w.get_pid()};
            }));
    }

    PointerPosition() {
        const [x, y] = global.get_pointer();
        return [x, y];
    }

    ShellState() {
        return JSON.stringify({overview: Main.overview.visible || Main.overview.visibleTarget ||
                Main.overview.animationInProgress, modalCount: Main.modalCount,
            actionMode: Main.actionMode, sessionMode: Main.sessionMode.currentMode,
            locked: Main.screenShield?.locked ?? null, focus: global.display.focus_window?.get_title() ?? null});
    }

    // The Shell opens the overview at start-up when the session begins without windows.
    HideOverview() {
        Main.overview.hide();
    }

    // PNG of the whole virtual screen.
    CaptureAsync([path], invocation) {
        const shot = new Shell.Screenshot();
        const stream = Gio.File.new_for_path(path).replace(null, false, Gio.FileCreateFlags.NONE, null);
        shot.screenshot(true, stream, (o, res) => {
            try {
                o.screenshot_finish(res);
                stream.close(null);
                invocation.return_value(new GLib.Variant('(s)', [path]));
            } catch (e) {
                invocation.return_error_literal(Gio.DBusError, Gio.DBusError.FAILED, `${e}`);
            }
        });
    }

    Place(id, x, y, w, h) {
        const win = this._window(id);
        if (win.is_maximized())
            win.unmaximize();
        win.move_resize_frame(false, x, y, w, h);
        win.activate(global.get_current_time());
    }

    Pointer(x, y) {
        this._pointer.notify_absolute_motion(now(), x, y);
    }

    // Smooth pointer travel clocked by the Shell (one motion event every 8 ms, ease in-out); returns at once.
    Glide(x, y, seconds) {
        const [x0, y0] = global.get_pointer();
        const t0 = now();
        if (this._glide)
            GLib.source_remove(this._glide);
        this._glide = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 8, () => {
            const t = Math.min(1, (now() - t0) / (seconds * 1e6));
            const e = t * t * (3 - 2 * t);
            this._pointer?.notify_absolute_motion(now(), x0 + (x - x0) * e, y0 + (y - y0) * e);
            if (t < 1)
                return GLib.SOURCE_CONTINUE;
            this._glide = 0;
            return GLib.SOURCE_REMOVE;
        });
    }

    Button(button, pressed) {
        this._pointer.notify_button(now(), button, pressed ? Clutter.ButtonState.PRESSED : Clutter.ButtonState.RELEASED);
    }

    Key(keyval, pressed) {
        this._keyboard.notify_keyval(now(), keyval, pressed ? Clutter.KeyState.PRESSED : Clutter.KeyState.RELEASED);
    }

    SlowDown(factor) {
        St.Settings.get().slow_down_factor = factor > 0 ? factor : 1;
    }

    SetSetting(key, json) {
        // The schema shipped in Window Magnet's own directory, whatever its state.
        const dir = Main.extensionManager.lookup(MAGNET).dir.get_child('schemas').get_path();
        const source = Gio.SettingsSchemaSource.new_from_directory(dir, Gio.SettingsSchemaSource.get_default(), false);
        const schema = source.lookup('org.gnome.shell.extensions.window-magnet', false);
        const settings = new Gio.Settings({settings_schema: schema});
        const value = JSON.parse(json);
        if (typeof value === 'boolean')
            settings.set_boolean(key, value);
        else
            settings.set_int(key, value);
    }

    SetEnabled(enabled) {
        if (enabled)
            Main.extensionManager.enableExtension(MAGNET);
        else
            Main.extensionManager.disableExtension(MAGNET);
    }

    State() {
        const ext = Main.extensionManager.lookup(MAGNET);
        return JSON.stringify({state: ext?.state ?? null, error: ext?.error ? `${ext.error}` : ''});
    }

    HideRecordingIndicator() {
        const area = Main.panel.statusArea;
        for (const indicator of [area.screenRecording, area.screenSharing, area.quickSettings?._remoteAccess]) {
            if (!indicator)
                continue;
            indicator.hide();
            indicator.connect('notify::visible', () => indicator.visible && indicator.hide());
        }
    }
}
