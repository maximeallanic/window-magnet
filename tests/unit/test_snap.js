// Run: gjs -m tests/unit/test_snap.js
import {snapPosition, snapResize, resizedRect, candidateLines, sameRect} from '../../extension/snap.js';
import {eq} from './assert.js';

const area = {x: 0, y: 0, width: 1920, height: 1080};
const other = {x: 500, y: 100, width: 400, height: 300};

eq(snapPosition({x: 910, y: 120, width: 300, height: 200}, [other], area, 16), {x: 900, y: 120}, 'left edge to the other\'s right edge');
eq(snapPosition({x: 190, y: 100, width: 300, height: 200}, [other], area, 16), {x: 200, y: 100}, 'right edge to the other\'s left edge');
eq(snapPosition({x: 905, y: 108, width: 300, height: 200}, [other], area, 16), {x: 900, y: 100}, 'tops aligned');
eq(snapPosition({x: 930, y: 130, width: 300, height: 200}, [other], area, 16), {x: 930, y: 130}, 'beyond the threshold');
eq(snapPosition({x: 910, y: 600, width: 300, height: 200}, [other], area, 16), {x: 910, y: 600}, 'no overlap on the other axis');
eq(snapPosition({x: 7, y: 1000, width: 300, height: 70}, [], area, 16), {x: 0, y: 1010}, 'screen edges');
eq(snapPosition({x: 7, y: 1000, width: 300, height: 70}, [], null, 16), {x: 7, y: 1000}, 'screen edges off');
eq(snapPosition({x: 910, y: 120, width: 300, height: 200}, [other], area, 8), {x: 910, y: 120}, 'smaller threshold');
eq(snapPosition({x: 903, y: 120, width: 300, height: 200}, [other, {x: 1210, y: 0, width: 100, height: 900}], area, 16),
    {x: 900, y: 120}, 'nearest line wins (3 px left rather than 7 px right)');

eq(snapResize({x: 100, y: 100, width: 395, height: 200}, {e: true}, [other], area, 16),
    {x: 100, y: 100, width: 400, height: 200}, 'resize: right edge');
eq(snapResize({x: 8, y: 100, width: 492, height: 200}, {w: true}, [], area, 16),
    {x: 0, y: 100, width: 500, height: 200}, 'resize: left edge to the screen');
eq(snapResize({x: 905, y: 108, width: 300, height: 192}, {w: true}, [other], area, 16),
    {x: 900, y: 108, width: 305, height: 192}, 'resize: west edge leaves the right edge alone');
eq(snapResize({x: 600, y: 90, width: 300, height: 305}, {s: true}, [other], area, 16),
    {x: 600, y: 90, width: 300, height: 310}, 'resize: bottom edge');
eq(snapResize({x: 100, y: 100, width: 395, height: 200}, {s: true}, [other], area, 16),
    {x: 100, y: 100, width: 395, height: 200}, 'resize: an edge not dragged does not move');

const start = {x: 100, y: 100, width: 400, height: 300};
eq(resizedRect(start, {e: true, s: true}, 12, -7), {x: 100, y: 100, width: 412, height: 293}, 'pointer, south-east');
eq(resizedRect(start, {w: true, n: true}, 12, -7), {x: 112, y: 93, width: 388, height: 307}, 'pointer, north-west');
eq(resizedRect(start, {e: true}, 12, -7), {x: 100, y: 100, width: 412, height: 300}, 'pointer, east ignores dy');

eq(candidateLines({x: 0, y: 0, width: 10, height: 10}, [], null, 16), {xs: [], ys: []}, 'nothing to snap to');
eq([sameRect(start, {...start}), sameRect(start, {...start, x: 1})], [true, false], 'sameRect');
print('test_snap: OK');
