// Window Magnet: while a window is moved or resized, its edges snap to the edges of the other windows and of the
// screen's work area; the visible jump of a snap is caught up by a spring. Optionally, a tab dropped on the desktop
// opens its window where it was dropped (dropPlacer.js).
//
// Pure maths are in snap.js, jump.js and drop.js (unit-tested headless); this file only wires them to Mutter.
import Meta from 'gi://Meta';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

import {snapPosition, snapResize, resizedRect, sameRect} from './snap.js';
import {snapJump} from './jump.js';
import {SpringBack} from './springBack.js';
import {DropPlacer} from './dropPlacer.js';

// Edges dragged by each resize grab.
const RESIZE_EDGES = {
    [Meta.GrabOp.RESIZING_N]: {n: true},
    [Meta.GrabOp.RESIZING_S]: {s: true},
    [Meta.GrabOp.RESIZING_E]: {e: true},
    [Meta.GrabOp.RESIZING_W]: {w: true},
    [Meta.GrabOp.RESIZING_NE]: {n: true, e: true},
    [Meta.GrabOp.RESIZING_NW]: {n: true, w: true},
    [Meta.GrabOp.RESIZING_SE]: {s: true, e: true},
    [Meta.GrabOp.RESIZING_SW]: {s: true, w: true},
};

const isMove = op => op === Meta.GrabOp.MOVING || op === Meta.GrabOp.MOVING_UNCONSTRAINED;

export default class WindowMagnetExtension extends Extension {
    enable() {
        this._settings = this.getSettings();
        this._springBack = new SpringBack();
        this._window = null;
        this._windowIds = null;
        this._stageId = 0;
        this._edges = null;
        this._resizeStart = null;
        this._lastPointer = null;
        this._previous = null;
        this._placing = false;
        this._dropPlacer = null;
        this._syncDropPlacer();
        this._settingsId = this._settings.connect('changed::place-dropped-tabs', () => this._syncDropPlacer());
        this._beginId = global.display.connect('grab-op-begin', (_display, win, op) => {
            if (isMove(op))
                this._follow(win, null);
            else if (RESIZE_EDGES[op] && this._settings.get_boolean('snap-while-resizing'))
                this._follow(win, RESIZE_EDGES[op]);
        });
        this._endId = global.display.connect('grab-op-end', () => {
            this._snapResizeEnd();
            this._release();
        });
    }

    disable() {
        global.display.disconnect(this._beginId);
        global.display.disconnect(this._endId);
        this._settings.disconnect(this._settingsId);
        this._release();
        this._dropPlacer?.destroy();
        this._dropPlacer = null;
        // Springs stopped; actors offset by this extension put back to 0 (nothing stays offset).
        this._springBack.destroy();
        this._springBack = null;
        this._settings = null;
    }

    _syncDropPlacer() {
        const wanted = this._settings.get_boolean('place-dropped-tabs');
        if (wanted && !this._dropPlacer) {
            this._dropPlacer = new DropPlacer();
        } else if (!wanted && this._dropPlacer) {
            this._dropPlacer.destroy();
            this._dropPlacer = null;
        }
    }

    _follow(win, edges) {
        this._release();
        if (!win)
            return;
        this._window = win;
        this._edges = edges;
        this._previous = null;
        // Resize: Mutter computes the raw size (initial rect + pointer delta) in a BEFORE_REDRAW "later", run on the
        // stage's before-update signal. Connected after Mutter, this handler runs right after it and sends the snapped
        // size in the same frame: the Wayland client only receives grouped configures and applies the last one.
        // Correcting on size-changed (after the client's commit) made the window alternate between both sizes.
        if (edges) {
            const [px, py] = global.get_pointer();
            this._resizeStart = {rect: win.get_frame_rect(), px, py};
            this._lastPointer = null;
            this._stageId = global.stage.connect('before-update', () => this._snapResizing(win));
            return;
        }
        const snap = () => this._snapMoving(win);
        this._windowIds = [win.connect('position-changed', snap), win.connect('size-changed', snap)];
    }

    _release() {
        if (this._window && this._windowIds)
            this._windowIds.forEach(id => this._window.disconnect(id));
        if (this._stageId)
            global.stage.disconnect(this._stageId);
        this._stageId = 0;
        this._window = null;
        this._windowIds = null;
        this._edges = null;
        this._resizeStart = null;
        this._previous = null;
    }

    get _threshold() {
        return this._settings.get_int('snap-threshold');
    }

    _workArea(win) {
        return this._settings.get_boolean('snap-to-screen-edges') ? win.get_work_area_current_monitor() : null;
    }

    // Frames of the other normal, visible windows on the same workspace and monitor.
    _others(win) {
        if (!this._settings.get_boolean('snap-to-windows'))
            return [];
        return global.get_window_actors()
            .map(actor => actor.meta_window)
            .filter(w => w !== win && !w.minimized && !w.is_hidden() &&
                w.get_window_type() === Meta.WindowType.NORMAL &&
                w.located_on_workspace(win.get_workspace()) &&
                w.get_monitor() === win.get_monitor())
            .map(w => w.get_frame_rect());
    }

    _aimedRect() {
        const {rect, px, py} = this._resizeStart;
        const [x, y] = global.get_pointer();
        return resizedRect(rect, this._edges, x - px, y - py);
    }

    _snappedResize(win) {
        const aimed = this._aimedRect();
        const snapped = snapResize(aimed, this._edges, this._others(win), this._workArea(win), this._threshold);
        return {aimed, snapped};
    }

    _snapResizing(win) {
        // Mutter only recomputes the size when the pointer moved: otherwise there is nothing to correct.
        const [x, y] = global.get_pointer();
        if (this._lastPointer && this._lastPointer[0] === x && this._lastPointer[1] === y)
            return;
        this._lastPointer = [x, y];
        const {aimed, snapped} = this._snappedResize(win);
        if (!sameRect(aimed, snapped))
            win.move_resize_frame(true, snapped.x, snapped.y, snapped.width, snapped.height);
    }

    _snapResizeEnd() {
        const win = this._window;
        if (!win || !this._edges || !this._resizeStart)
            return;
        const {aimed, snapped} = this._snappedResize(win);
        if (!sameRect(aimed, snapped))
            win.move_resize_frame(true, snapped.x, snapped.y, snapped.width, snapped.height);
    }

    _snapMoving(win) {
        if (this._placing)
            return;
        const rect = win.get_frame_rect();
        const snapped = snapPosition(rect, this._others(win), this._workArea(win), this._threshold);
        const raw = {x: rect.x, y: rect.y};
        const placed = snapped.x !== rect.x || snapped.y !== rect.y ? snapped : raw;
        if (this._settings.get_boolean('spring-animation')) {
            const jump = snapJump(this._previous, raw, placed);
            if (jump.dx || jump.dy)
                this._springBack.jump(win.get_compositor_private(), jump);
        }
        this._previous = {raw, placed};
        if (placed === raw)
            return;
        // move_frame emits position-changed synchronously: ignore our own move.
        this._placing = true;
        win.move_frame(true, placed.x, placed.y);
        this._placing = false;
    }
}
