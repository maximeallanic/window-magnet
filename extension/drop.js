// Pure placement of a window born from a tab dropped on the desktop, no GNOME dependency (tested by
// tests/unit/test_drop.js). Rect: {x, y, width, height}.

function clamp(v, min, max) {
    return Math.max(min, Math.min(v, max));
}

// drop: {pid, at} recorded when a drag ended, or null. True when a window of process `pid` created at `now`
// (ms) is the one that drag produced.
export function matchesDrop(drop, pid, now, delayMs) {
    return !!drop && drop.pid === pid && now - drop.at <= delayMs;
}

// The window's top-left corner lands on the anchor (top-left corner of the tab preview that was being
// dragged), held inside the work area of the monitor the tab was dropped on.
//   anchor   : {x, y}
//   size     : {width, height} wanted for the window
//   workArea : rect
export function dropGeometry({anchor, size, workArea}) {
    const width = Math.min(size.width, workArea.width);
    const height = Math.min(size.height, workArea.height);
    return {
        x: clamp(Math.round(anchor.x), workArea.x, workArea.x + workArea.width - width),
        y: clamp(Math.round(anchor.y), workArea.y, workArea.y + workArea.height - height),
        width,
        height,
    };
}
