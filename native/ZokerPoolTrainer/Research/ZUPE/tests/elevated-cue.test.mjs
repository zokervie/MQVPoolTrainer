
import assert from 'node:assert/strict';
import { CUE_PRESETS, strike3D, traceElevatedShot, compareReference, classifyShot } from '../enhancements/elevated-cue-3d.mjs';
const regular=strike3D({cue:CUE_PRESETS.zokerPlaying,elevationDeg:0,speed:2});
assert.ok(Math.abs(regular.velocity.y)<1e-12);
const elevated=strike3D({cue:CUE_PRESETS.zokerJump,elevationDeg:45,speed:3.2});
assert.ok(elevated.velocity.y<0,'cue delivers downward impulse');
const jump=traceElevatedShot({cue:CUE_PRESETS.zokerJump,elevationDeg:45,speed:3.2},{duration:.7});
assert.ok(Number.isFinite(jump.maxClearance));
assert.ok(jump.maxClearance>0.0001,`jump clearance = ${jump.maxClearance}`);
assert.equal(classifyShot({trajectory:jump,tipSide:0,elevationDeg:45}),'jump');
assert.equal(compareReference({landingX:1,landingZ:2,height:.5},{landingX:1,landingZ:2,height:.5}),0);
assert.throws(()=>strike3D({tipSide:1}));
const replay=traceElevatedShot({cue:CUE_PRESETS.zokerJump,elevationDeg:45,speed:3.2},{duration:.7});
assert.deepEqual(jump.points,replay.points);
console.log('PASS: cue presets, downward impulse, slate-generated jump, repeatability, reference loss');
