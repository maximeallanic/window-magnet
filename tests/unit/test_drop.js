// Run: gjs -m tests/unit/test_drop.js
import {dropGeometry, matchesDrop} from '../../extension/drop.js';
import {eq} from './assert.js';

const AREA = {x: 0, y: 36, width: 5120, height: 1404};
const S = (width, height) => ({width, height});

eq(dropGeometry({anchor: {x: 2800, y: 480}, size: S(900, 700), workArea: AREA}),
    {x: 2800, y: 480, width: 900, height: 700}, 'top-left corner lands on the anchor');

eq(dropGeometry({anchor: {x: 2800, y: 480}, size: S(1272, 1351), workArea: AREA}),
    {x: 2800, y: 89, width: 1272, height: 1351}, 'bottom edge held in the work area');

eq(dropGeometry({anchor: {x: 5000, y: 280}, size: S(900, 700), workArea: AREA}),
    {x: 4220, y: 280, width: 900, height: 700}, 'right edge held in the work area');

eq(dropGeometry({anchor: {x: -40, y: 10}, size: S(900, 700), workArea: AREA}),
    {x: 0, y: 36, width: 900, height: 700}, 'left and top edges held in the work area');

eq(dropGeometry({anchor: {x: 5400, y: 400}, size: S(2400, 1404), workArea: {x: 5120, y: 36, width: 1500, height: 964}}),
    {x: 5120, y: 36, width: 1500, height: 964}, 'larger than the target monitor: shrunk to its work area');

eq(dropGeometry({anchor: {x: 2800.6, y: 480.4}, size: S(900, 700), workArea: AREA}),
    {x: 2801, y: 480, width: 900, height: 700}, 'fractional anchor rounded to whole pixels');

const drop = {pid: 42, at: 1000};
eq(matchesDrop(drop, 42, 1040, 500), true, 'same process shortly after the drop');
eq(matchesDrop(drop, 43, 1040, 500), false, 'another process');
eq(matchesDrop(drop, 42, 1600, 500), false, 'too long after the drop');
eq(matchesDrop(null, 42, 1040, 500), false, 'no drop recorded');
print('test_drop: OK');
