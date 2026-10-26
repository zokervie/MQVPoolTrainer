import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {DEFAULT,makeBall,railResponse,simulateRails,finalLegClosest,searchBankRoute} from '../enhancements/bank-physics.mjs';
import {traceElevatedShot} from '../enhancements/elevated-cue-3d.mjs';
const near=(a,b,e=1e-8)=>assert.ok(Math.abs(a-b)<=e,`${a} != ${b}`);
// Independent cross-product convention: at +x contact, omega +y gives surface -z.
const r=DEFAULT.radius,I=.4*DEFAULT.mass*r*r;
let b=makeBall({vx:1,vz:.4,wy:.4/r});
const before={...b};const hit=railResponse(b,{x:1,z:0});
near(hit.incidentSlip,0);near(b.vz,before.vz);near(b.wy,before.wy);
for(const n of [{x:1,z:0},{x:-1,z:0},{x:0,z:1},{x:0,z:-1}]){
 for(const spin of [-100,0,100]){
  const b=makeBall({vx:n.x*2-n.z*.3,vz:n.z*2+n.x*.3,wy:spin});
  const energy=x=>.5*DEFAULT.mass*(x.vx*x.vx+x.vz*x.vz)+.5*I*x.wy*x.wy;
  const e=energy(b);railResponse(b,n);assert.ok(energy(b)<=e+1e-10,'passive rail must not add energy');
 }
}
const half=DEFAULT.length/2-r;
const path=simulateRails(makeBall({vx:2,wz:-2/r}),{...DEFAULT,muRoll:0,spinDecel:0,eRail:.8,muRail:0,railSpeedSensitivity:0},{maxEvents:2,maxTime:5,sampleInterval:.07});
near(path.events[0].t,half/2,1e-8);near(path.events[0].x,half);
assert.ok(path.points.every((p,i,a)=>i===0||p.t>a[i-1].t));
assert.ok(path.points.every(p=>Math.abs(p.x)<=half+1e-9));
// A target in the MIDDLE of the complete final leg must not be missed.
const trace={events:[{t:1,x:1,z:0},{t:4,x:-1,z:0}],points:[{t:1,x:1,z:0},{t:2,x:.4,z:0},{t:3,x:-.4,z:0},{t:4,x:-1,z:0}]};
near(finalLegClosest(trace,{x:0,z:.01},1).error,.01);
assert.ok(finalLegClosest(trace,{x:0,z:0},1).time>1);
const params={...DEFAULT,muRoll:0,eRail:.8,muRail:0,railSpeedSensitivity:0};
const results=searchBankRoute({start:{x:0,z:0},target:{x:0,z:0},rails:['right'],speeds:[2],angleSamples:5,params,tolerance:.005});
assert.ok(results.some(x=>Math.abs(x.angle)<1e-9&&x.closest.time>x.trace.events[0].t));
assert.throws(()=>simulateRails(makeBall(),DEFAULT,{maxTime:Infinity}));
assert.throws(()=>traceElevatedShot({speed:NaN}));
const jump=traceElevatedShot({elevationDeg:45,speed:3},{duration:.1});
near(jump.points[0].t,0);near(jump.points.at(-1).t,.1);
assert.ok(jump.points.every((p,i,a)=>i===0||p.t>a[i-1].t));
// Exercise the EXACT offline HTML bundle loaded by the native controller.
const html=fs.readFileSync(new URL('../../../BankLab/ZupeLab/index.html',import.meta.url),'utf8');
const scripts=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(x=>x[1]);
assert.equal(scripts.length,2);
const captured=[];
const noop=()=>{};
const canvasContext=new Proxy({}, {get:(o,k)=>o[k]??noop,set:(o,k,v)=>(o[k]=v,true)});
function element(id,value=''){
 return {id,value,textContent:'',disabled:false,width:600,height:310,files:[],children:[],handlers:{},dataset:{},
  style:{setProperty:noop},classList:{toggle:noop},append(...x){this.children.push(...x);},
  replaceChildren(...x){this.children=x;},addEventListener(k,f){this.handlers[k]=f;},
  getContext:()=>canvasContext,getBoundingClientRect:()=>({width:600,height:310,top:0,left:0}),setPointerCapture:noop};
}
const elements=new Map();for(const [,id] of html.matchAll(/id="([^"]+)"/g))elements.set(id,element(id));
for(const [id,value] of Object.entries({speed:'3',angle:'23',side:'0',rail:'.82',cue:'zokerJump',elevation:'45',top:'0',rails:'2',timeline:'1'}))elements.get(id).value=value;
const tabs=['bank','elevated','stroke','golden'].map(x=>{const e=element(x);e.dataset.tab=x;return e;});
const sandbox={console,performance:{now:()=>0},devicePixelRatio:1,requestAnimationFrame:noop,
 document:{getElementById:id=>elements.get(id),querySelectorAll:()=>tabs,createElement:()=>element('new')},
 window:{addEventListener:noop,webkit:{messageHandlers:{zupeExport:{postMessage:m=>captured.push(m)}}}}};
vm.createContext(sandbox);for(const source of scripts)new vm.Script(source).runInContext(sandbox);
assert.equal(elements.get('export').disabled,false);
elements.get('export').handlers.click();assert.equal(JSON.parse(captured.at(-1).text).model,'ZUPE-box-rail-research');
tabs[1].handlers.click();elements.get('export').handlers.click();assert.equal(JSON.parse(captured.at(-1).text).model,'ZUPE-two-stage-cue-slate-research');
elements.get('speed').handlers.input();assert.equal(elements.get('export').disabled,true,'never export a stale trajectory');
elements.get('run').handlers.click();assert.equal(elements.get('export').disabled,false);
tabs[2].handlers.click();const pad=elements.get('strokeArea');
const ev=(y,t)=>({pointerId:1,clientX:100,clientY:y,timeStamp:t});
pad.handlers.pointerdown(ev(160,0));pad.handlers.pointermove(ev(180,10));pad.handlers.pointerup(ev(185,20));
assert.equal(elements.get('export').disabled,true,'finger-up cannot synthesize impact');
pad.handlers.pointerdown(ev(160,100));pad.handlers.pointermove(ev(180,110));pad.handlers.pointermove(ev(145,120));pad.handlers.pointermove(ev(110,130));
assert.equal(elements.get('export').disabled,false,'crossing gate records real measured pointer samples');
tabs[3].handlers.click();const initial=makeBall({vx:1.3,vz:.2});const fixture=simulateRails(initial,DEFAULT,{maxEvents:1,maxTime:8});
const data=['train','validation'].map((partition,i)=>({id:`fixture-${i}`,partition,initial,railSequence:fixture.events.map(e=>e.rail),observed:{contacts:fixture.events.map(e=>({x:e.x,z:e.z})),uncertaintyMeters:.01},provenance:{source:'synthetic test only',method:'regression fixture'}}));
elements.get('dataset').value=JSON.stringify(data);elements.get('evaluate').handlers.click();assert.equal(elements.get('error').textContent,'');
elements.get('export').handlers.click();assert.equal(captured.at(-1).name,'ZUPE-calibration.json');
elements.get('fit').handlers.click();assert.equal(elements.get('error').textContent,'');
elements.get('dataset').handlers.input();assert.equal(elements.get('export').disabled,true);
console.log('PASS: analytic rail sign/energy, residual flight, complete final leg, trace timestamps, all four Lab tabs, native export messages, stroke gate, holdout and stale-export guards');
