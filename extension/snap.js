// Pure snapping maths, no GNOME dependency (unit-tested headless by tests/unit/test_snap.js).
// Rect: {x, y, width, height}, logical pixels.
//
// A window edge snaps to a candidate line when it is within `threshold` pixels of it. Candidate lines come from the
// work area edges and from the edges of the other windows; another window only counts on one axis when it overlaps
// the moved window on the other axis (within `threshold`), so a window far above does not pull a vertical edge.

// The smallest correction (signed) that brings either edge [start, start + size] onto a line, or 0.
function bestOffset(start, size, lines, threshold) {
    let best = null;
    for (const line of lines) {
        for (const delta of [line - start, line - (start + size)]) {
            if (Math.abs(delta) <= threshold && (best === null || Math.abs(delta) < Math.abs(best)))
                best = delta;
        }
    }
    return best ?? 0;
}

// The smallest correction (signed) that brings one edge at `edge` onto a line, or 0.
function edgeOffset(edge, lines, threshold) {
    let best = null;
    for (const line of lines) {
        const delta = line - edge;
        if (Math.abs(delta) <= threshold && (best === null || Math.abs(delta) < Math.abs(best)))
            best = delta;
    }
    return best ?? 0;
}

function overlaps(a0, a1, b0, b1, margin) {
    return a0 < b1 + margin && b0 < a1 + margin;
}

// Vertical lines (x) and horizontal lines (y) that `rect` may snap to.
//   others   : rects of the other windows (empty when snapping to windows is off)
//   workArea : rect, or null when snapping to the screen edges is off
export function candidateLines(rect, others, workArea, threshold) {
    const xs = workArea ? [workArea.x, workArea.x + workArea.width] : [];
    const ys = workArea ? [workArea.y, workArea.y + workArea.height] : [];
    for (const o of others) {
        if (overlaps(rect.y, rect.y + rect.height, o.y, o.y + o.height, threshold))
            xs.push(o.x, o.x + o.width);
        if (overlaps(rect.x, rect.x + rect.width, o.x, o.x + o.width, threshold))
            ys.push(o.y, o.y + o.height);
    }
    return {xs, ys};
}

// Move: both edges of each axis are tried, the size never changes. Returns the corrected position {x, y}.
export function snapPosition(rect, others, workArea, threshold) {
    const {xs, ys} = candidateLines(rect, others, workArea, threshold);
    return {
        x: rect.x + bestOffset(rect.x, rect.width, xs, threshold),
        y: rect.y + bestOffset(rect.y, rect.height, ys, threshold),
    };
}

// Resize: only the edges being dragged (edges: {n, s, e, w} booleans) snap. Returns the corrected rect.
export function snapResize(rect, edges, others, workArea, threshold) {
    const {xs, ys} = candidateLines(rect, others, workArea, threshold);
    let left = rect.x, right = rect.x + rect.width;
    let top = rect.y, bottom = rect.y + rect.height;
    if (edges.w)
        left += edgeOffset(left, xs, threshold);
    if (edges.e)
        right += edgeOffset(right, xs, threshold);
    if (edges.n)
        top += edgeOffset(top, ys, threshold);
    if (edges.s)
        bottom += edgeOffset(bottom, ys, threshold);
    return {x: left, y: top, width: right - left, height: bottom - top};
}

// The rect Mutter aims at during a resize: initial rect plus the pointer travel applied to the dragged edges
// (independent of the size the Wayland client actually committed).
export function resizedRect(initial, edges, dx, dy) {
    let left = initial.x, right = initial.x + initial.width;
    let top = initial.y, bottom = initial.y + initial.height;
    if (edges.w)
        left += dx;
    if (edges.e)
        right += dx;
    if (edges.n)
        top += dy;
    if (edges.s)
        bottom += dy;
    return {x: left, y: top, width: right - left, height: bottom - top};
}

export function sameRect(a, b) {
    return a.x === b.x && a.y === b.y && a.width === b.width && a.height === b.height;
}
