// Places a window born from a tab dropped on the desktop where the tab was dropped, at the size of the
// window it came from. Wayland clients cannot position their own windows, so the compositor does it.
//
// Mutter shows a drag as a MetaDnDActor in its feedback group; the actor is the dragged preview and knows the
// surface the drag started from. A normal window created by the same process right after that actor goes
// away is the detached tab.
// Timing, measured on Mutter 51:
//  - the size is requested at `window-created`, so it travels in the first configure and the first frame is
//    already right (requested at `shown`, the window is painted ~100 ms at its default size and place);
//  - the position is applied at `shown`: Mutter's own placement runs just before and overrides anything sent
//    earlier. A plain move takes effect at once, before the first frame.
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Meta from 'gi://Meta';
import Mtk from 'gi://Mtk';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {dropGeometry, matchesDrop} from './drop.js';

const DRAG_ACTOR = 'MetaDnDActor';
const DELAY_MS = 500; // a detached tab's window was measured 30–130 ms after the drop

function now() {
    return GLib.get_monotonic_time() / 1000;
}

function originWindow(dragActor) {
    let actor = dragActor.drag_origin;
    while (actor && !actor.meta_window)
        actor = actor.get_parent();
    return actor?.meta_window ?? null;
}

export class DropPlacer {
    constructor() {
        this._drags = new Map();   // drag actor → {pid, originSize}
        this._pending = new Map(); // window → signal ids, until it is shown
        this._drop = null;
        this._feedback = global.compositor.get_feedback_group();
        this._feedbackIds = [
            this._feedback.connect('child-added', (_g, child) => this._dragBegan(child)),
            this._feedback.connect('child-removed', (_g, child) => this._dragEnded(child)),
        ];
        this._createdId = global.display.connect('window-created', (_d, win) => this._windowCreated(win));
    }

    destroy() {
        this._feedbackIds.forEach(id => this._feedback.disconnect(id));
        global.display.disconnect(this._createdId);
        for (const [win, ids] of this._pending)
            ids.forEach(id => win.disconnect(id));
        this._pending.clear();
        this._drags.clear();
        this._drop = null;
    }

    _dragBegan(child) {
        if (GObject.type_name(child.constructor.$gtype) !== DRAG_ACTOR)
            return;
        const win = originWindow(child);
        if (!win)
            return;
        const rect = win.get_frame_rect();
        // A maximized or fullscreen origin has no size worth copying: the new window keeps its default one.
        const floating = win.get_maximize_flags() === 0 && !win.is_fullscreen();
        this._drags.set(child, {
            pid: win.get_pid(),
            originSize: floating ? {width: rect.width, height: rect.height} : null,
        });
    }

    _dragEnded(child) {
        const drag = this._drags.get(child);
        if (!drag)
            return;
        this._drags.delete(child);
        const [x, y] = child.get_transformed_position();
        const [px, py] = global.get_pointer();
        const monitor = global.display.get_monitor_index_for_rect(new Mtk.Rectangle({x: px, y: py, width: 1, height: 1}));
        this._drop = {
            ...drag,
            anchor: {x, y},
            workArea: Main.layoutManager.getWorkAreaForMonitor(monitor),
            at: now(),
        };
    }

    _windowCreated(win) {
        if (win.get_window_type() !== Meta.WindowType.NORMAL || !matchesDrop(this._drop, win.get_pid(), now(), DELAY_MS))
            return;
        const {anchor, workArea, originSize} = this._drop;
        this._drop = null;
        if (originSize) {
            const g = dropGeometry({anchor, size: originSize, workArea});
            win.move_resize_frame(true, g.x, g.y, g.width, g.height);
        }
        const forget = () => {
            this._pending.get(win)?.forEach(id => win.disconnect(id));
            this._pending.delete(win);
        };
        this._pending.set(win, [
            win.connect('shown', () => {
                forget();
                const rect = win.get_frame_rect();
                const g = dropGeometry({anchor, size: {width: rect.width, height: rect.height}, workArea});
                win.move_frame(true, g.x, g.y);
            }),
            win.connect('unmanaged', forget),
        ]);
    }
}
