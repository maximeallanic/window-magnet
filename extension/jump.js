// Pure computation of the visible jump caused by a snap (FLIP technique), no GNOME dependency
// (unit-tested headless by tests/unit/test_jump.js).
//
// On every position change during a move: `raw` is the position Mutter computed from the pointer, `placed` the
// position actually set (snapped or raw). On one axis the window "should" have stayed where it was if it was already
// snapped on that axis, or followed the pointer otherwise. The gap between that natural position and the placed one is
// the visible jump; the window actor is offset by it and a spring brings the offset back to 0.
//   previous : {raw: {x, y}, placed: {x, y}} of the previous call, or null at the start of the move.
// Returns {dx, dy} to add to the actor's translation.
export function snapJump(previous, raw, placed) {
    if (!previous)
        return {dx: 0, dy: 0};
    const axis = a => {
        const wasSnapped = previous.placed[a] !== previous.raw[a];
        const natural = wasSnapped ? previous.placed[a] : raw[a];
        return natural - placed[a];
    };
    return {dx: axis('x'), dy: axis('y')};
}
