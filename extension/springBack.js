// The snap jump on a spring: when a window's real position jumps (snap, release, change of target), its actor is
// offset by the same amount and brought back to 0 by the Material 3 Expressive "FastSpatial" spring of the vendored
// toolkit (m3e/). Interruptible: a new jump starts from the current translation and velocity. The real position
// (snapping, work area) is never animated, only the actor's translation.
//
// The toolkit honours GNOME's "enable-animations" setting and "slow down animations": with animations off the
// translation is written at its target at once, so the window simply jumps.
//
// m3e/ is an unmodified copy of shared/m3e/{animate,track,spring,curve,tokens}.js of m3e-gnome-extensions
// (https://github.com/maximeallanic/m3e-gnome-extensions, MIT, Copyright (c) 2026 Maxime Allanic); m3e/spring.js
// ports the spring maths of AndroidX Compose (Apache-2.0). Commit and checksums: vendor/m3e.lock in the repository.
import {currentState, release, stopAll} from './m3e/animate.js';

const SPRING = 'FastSpatial';
const PROPS = {dx: 'translation_x', dy: 'translation_y'};

export class SpringBack {
    constructor() {
        this._actors = new Map(); // actor → {axes: {translation_x: Animation, translation_y: Animation}, destroyId}
    }

    // Offsets `actor` by {dx, dy} and springs the offset back to 0.
    jump(actor, offset) {
        if (!actor)
            return;
        let tracked = this._actors.get(actor);
        if (!tracked) {
            tracked = {axes: {}, destroyId: actor.connect('destroy', () => this._actors.delete(actor))};
            this._actors.set(actor, tracked);
        }
        for (const [key, prop] of Object.entries(PROPS)) {
            const delta = offset[key];
            if (!delta)
                continue;
            const state = currentState(actor, prop);
            const value = state?.value ?? actor[prop];
            const velocity = state?.velocity ?? 0;
            tracked.axes[prop]?.stop();
            actor[prop] = value + delta;
            tracked.axes[prop] = release(actor, prop, 0, velocity, SPRING);
        }
    }

    // Stops every spring, puts back to 0 the actors this instance offset (and only those) and disconnects their
    // 'destroy' handlers.
    destroy() {
        for (const [actor, {axes, destroyId}] of this._actors) {
            actor.disconnect(destroyId);
            for (const prop of Object.values(PROPS)) {
                axes[prop]?.stop();
                actor[prop] = 0;
            }
        }
        this._actors.clear();
        stopAll();
    }
}
