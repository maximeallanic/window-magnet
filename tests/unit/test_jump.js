// Run: gjs -m tests/unit/test_jump.js
import {snapJump} from '../../extension/jump.js';
import {eq} from './assert.js';

const P = (x, y) => ({x, y});
const step = (raw, placed) => ({raw, placed});

eq(snapJump(null, P(10, 10), P(0, 10)), {dx: 0, dy: 0}, 'start of the move: nothing');
eq(snapJump(step(P(30, 10), P(30, 10)), P(25, 10), P(25, 10)), {dx: 0, dy: 0}, 'free to free: nothing');
eq(snapJump(step(P(30, 10), P(30, 10)), P(12, 10), P(0, 10)), {dx: 12, dy: 0}, 'snap: a 12 px jump caught up');
eq(snapJump(step(P(12, 10), P(0, 10)), P(8, 10), P(0, 10)), {dx: 0, dy: 0}, 'stays snapped: nothing (pointer held)');
eq(snapJump(step(P(8, 10), P(0, 10)), P(-20, 10), P(-20, 10)), {dx: 20, dy: 0}, 'release: a -20 px jump caught up');
eq(snapJump(step(P(5, 10), P(0, 10)), P(5, 3), P(0, 0)), {dx: 0, dy: 3}, 'second axis snaps, first one kept');
eq(snapJump(step(P(503, 10), P(500, 10)), P(497, 10), P(496, 10)), {dx: 4, dy: 0}, 'change of snap target');
print('test_jump: OK');
