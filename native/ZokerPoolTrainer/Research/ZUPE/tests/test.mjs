import assert from 'node:assert/strict';
import {makeBall,railResponse,clothStep,simulateRails,diamondToMeters,DEFAULT} from '../enhancements/bank-physics.mjs';
import {analyzeStroke,contactGate} from '../enhancements/stroke-control.mjs';
const near=(a,b,e=1e-9)=>assert.ok(Math.abs(a-b)<=e,`${a} != ${b}`);
near(diamondToMeters(4,2).x,0);near(diamondToMeters(4,2).z,0);
for(const speed of [0.1,0.4,1.0,2.0,4]){
  const b=makeBall({vx:speed});const result=railResponse(b,{x:1,z:0});
  assert.ok(result.hit);assert.ok(b.vx<0);assert.ok(Math.abs(b.vx)<speed);
}
const a=makeBall({vx:1,vz:.4,wy:0}),b=makeBall({vx:1,vz:.4,wy:35});
railResponse(a,{x:1,z:0});railResponse(b,{x:1,z:0});assert.notEqual(a.vz,b.vz);
const slow=makeBall({vx:.2,wz:-.2/DEFAULT.radius});for(let i=0;i<500;i++)clothStep(slow);assert.ok(slow.vx<.2);
const input=Array.from({length:8},(_,i)=>({t:i*.01,x:0,y:i*2}));assert.ok(analyzeStroke(input).valid);
assert.ok(contactGate(-0.1,0.01,0));assert.equal(contactGate(.01,.02,0),false);
const trace=simulateRails(makeBall({vx:1.3,x:0,z:0}),DEFAULT,{maxEvents:2,maxTime:8});assert.ok(trace.events.length>=1);
assert.equal(trace.events[0].rail,'right');
console.log('PASS: diamond coordinates, speed/restitution, spin response, cloth deceleration, stroke touch, impact gating, rail events');
