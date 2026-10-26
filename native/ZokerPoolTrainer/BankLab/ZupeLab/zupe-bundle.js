globalThis.Zupe = (() => {
"use strict";
const bank = (() => {
/** Zoker Bank Physics Research Module - independent from game render loop.
 * SI units. This is a testable planar ball/rail model, NOT a verified replacement
 * for the project's full solver. Integration uses existing pocket/jaw geometry.
 */
const DEFAULT = Object.freeze({
  length:2.54,width:1.27,radius:0.028575,mass:0.17,
  gravity:9.81,muSlide:0.20,muRoll:0.011,spinDecel:10,
  eRail:0.82,muRail:0.20,railSpeedSensitivity:0.025,
  railHeight:0.0365, dt:1/2000
});
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const dot=(a,b)=>a.x*b.x+a.z*b.z;
const len=v=>Math.hypot(v.x,v.z);
const normal=v=>{const n=len(v);return n?{x:v.x/n,z:v.z/n}:{x:0,z:0}};
function makeBall({x=0,z=0,vx=0,vz=0,wx=0,wy=0,wz=0}={}) {return {x,z,vx,vz,wx,wy,wz};}
function railResponse(ball, outward, p=DEFAULT){
  // Planar rigid-body impulse at vertical rail contact; inward surface normal.
  // Outward is the normal toward a rail (ball's approach direction).
  const n=normal(outward),t={x:-n.z,z:n.x};
  const vn=ball.vx*n.x+ball.vz*n.z;
  if(vn<=0) return {hit:false,normalImpulse:0,tangentImpulse:0};
  const r=p.radius,m=p.mass,I=0.4*m*r*r;
  // Contact radius along horizontal outward normal. Spin around vertical alters slip.
  const vt=ball.vx*t.x+ball.vz*t.z - ball.wy*r;
  const e=clamp(p.eRail-p.railSpeedSensitivity*vn,0.4,0.95);
  const jn=-(1+e)*m*vn;
  const denom=1/m+r*r/I;
  const jt=clamp(-vt/denom,-p.muRail*Math.abs(jn),p.muRail*Math.abs(jn));
  ball.vx+=(jn*n.x+jt*t.x)/m;
  ball.vz+=(jn*n.z+jt*t.z)/m;
  // Spin coupling, sign follows contact-point velocity convention above.
  ball.wy-=r*jt/I;
  return {hit:true,normalImpulse:jn,tangentImpulse:jt,incidentNormalSpeed:vn,incidentSlip:vt,restitution:e};
}
function clothStep(b,p=DEFAULT,dt=p.dt){
  const r=p.radius,g=p.gravity;
  const ux=b.vx+r*b.wz, uz=b.vz-r*b.wx;
  const slip=Math.hypot(ux,uz);
  if(slip>0.0001){
    // Clamp to transition instead of overshooting kinetic friction.
    const t=Math.min(dt,slip/(3.5*p.muSlide*g));
    const ax=-p.muSlide*g*ux/slip, az=-p.muSlide*g*uz/slip;
    b.vx+=ax*t;b.vz+=az*t;
    b.wx+=(-az*2.5/r)*t;b.wz+=(ax*2.5/r)*t;
    if(t<dt){b.wx=b.vz/r;b.wz=-b.vx/r;}
  }else{
    const s=Math.hypot(b.vx,b.vz),ns=Math.max(0,s-p.muRoll*g*dt);
    if(s){b.vx*=ns/s;b.vz*=ns/s;}
    b.wx=b.vz/r;b.wz=-b.vx/r;
  }
  const dw=p.spinDecel*dt;
  b.wy=Math.sign(b.wy)*Math.max(0,Math.abs(b.wy)-dw);
  b.x+=b.vx*dt;b.z+=b.vz*dt;
  return b;
}
const RAILS={right:{x:1,z:0},left:{x:-1,z:0},bottom:{x:0,z:1},top:{x:0,z:-1}};
function simulateRails(initial,p=DEFAULT,{maxTime=25,maxEvents=4,sampleInterval=0.02,postFinalRailSeconds=0}={}){
  if(!Object.values(initial).every(Number.isFinite)||!Number.isFinite(p.dt)||p.dt<=0||p.dt>.005||
     !Number.isFinite(maxTime)||maxTime<=0||maxTime>30||!Number.isInteger(maxEvents)||maxEvents<1||maxEvents>20||
     !Number.isFinite(sampleInterval)||sampleInterval<=0||!Number.isFinite(postFinalRailSeconds)||postFinalRailSeconds<0||postFinalRailSeconds>15)
    throw Error('invalid simulation limits');
  if(!['length','width','radius','mass','gravity','muSlide','muRoll','spinDecel','eRail','muRail','railSpeedSensitivity'].every(k=>Number.isFinite(p[k]))||
     p.radius<=0||p.mass<=0||p.length<=2*p.radius||p.width<=2*p.radius||p.gravity<=0||p.muSlide<=0||p.muRoll<0||p.spinDecel<0||p.muRail<0)
    throw Error('invalid physical parameters');
  const b={...initial},events=[],points=[{t:0,x:b.x,z:b.z,wy:b.wy}];
  const halfX=p.length/2-p.radius,halfZ=p.width/2-p.radius;
  if(Math.abs(b.x)>halfX+1e-9||Math.abs(b.z)>halfZ+1e-9)throw Error('ball outside box rails');
  let finalTime=null,lastSample=0;
  const record=(t)=>{const point={t,x:b.x,z:b.z,wy:b.wy};
    if(Math.abs(points.at(-1).t-t)<1e-12)points[points.length-1]=point;else points.push(point);};
  for(let i=0;i<Math.ceil(maxTime/p.dt);i++){
    const start=i*p.dt,dt=Math.min(p.dt,maxTime-start);
    // Apply cloth velocity/spin changes once; integrate position in rail-event segments.
    const oldX=b.x,oldZ=b.z;clothStep(b,p,dt);b.x=oldX;b.z=oldZ;
    let remain=dt,used=0;
    for(let contact=0;remain>1e-12&&contact<8;contact++){
      const tx=b.vx>1e-12?(halfX-b.x)/b.vx:b.vx< -1e-12?(-halfX-b.x)/b.vx:Infinity;
      const tz=b.vz>1e-12?(halfZ-b.z)/b.vz:b.vz< -1e-12?(-halfZ-b.z)/b.vz:Infinity;
      const hitTime=Math.max(0,Math.min(tx,tz));
      if(hitTime>remain){b.x+=b.vx*remain;b.z+=b.vz*remain;used+=remain;remain=0;break;}
      b.x+=b.vx*hitTime;b.z+=b.vz*hitTime;used+=hitTime;remain-=hitTime;
      // Resolve simultaneous axis contacts in a fixed order (research box model).
      for(const [rail,axis,bound] of [
        ...(Math.abs(tx-hitTime)<1e-10?[[b.vx>0?'right':'left','x',b.vx>0?halfX:-halfX]]:[]),
        ...(Math.abs(tz-hitTime)<1e-10?[[b.vz>0?'bottom':'top','z',b.vz>0?halfZ:-halfZ]]:[])]){
        b[axis]=bound;const data=railResponse(b,RAILS[rail],p);
        if(data.hit){events.push({type:'rail',rail,t:start+used,x:b.x,z:b.z,...data});record(start+used);}
        if(events.length>=maxEvents&&finalTime===null)finalTime=start+used;
        if(events.length>=maxEvents&&postFinalRailSeconds===0)return {events,points,final:b,railCount:events.length};
      }
    }
    const t=start+dt;
    if(t-lastSample>=sampleInterval-1e-12){record(t);lastSample=t;}
    if(finalTime!==null&&(events.length>maxEvents||t>=finalTime+postFinalRailSeconds)){record(t);break;}
    if(Math.hypot(b.vx,b.vz)<1e-4&&Math.abs(b.wy)<1e-3){record(t);break;}
    if(i===Math.ceil(maxTime/p.dt)-1)record(t);
  }
  return {events,points,final:b,railCount:events.length};
}
function finalLegClosest(trace,target,railCount){
  if(!Number.isInteger(railCount)||railCount<1||trace.events.length<railCount)return null;
  const begin=trace.events[railCount-1],end=trace.events[railCount];
  const points=[{t:begin.t,x:begin.x,z:begin.z},...trace.points.filter(p=>p.t>begin.t+1e-10&&(!end||p.t<end.t-1e-10)),
    ...(end?[{t:end.t,x:end.x,z:end.z}]:[])];
  let best=null;
  for(let i=1;i<points.length;i++){
    const a=points[i-1],b=points[i],dx=b.x-a.x,dz=b.z-a.z,den=dx*dx+dz*dz;
    const f=den?clamp(((target.x-a.x)*dx+(target.z-a.z)*dz)/den,0,1):0;
    const x=a.x+f*dx,z=a.z+f*dz,error=Math.hypot(target.x-x,target.z-z);
    if(!best||error<best.error)best={error,x,z,time:a.t+f*(b.t-a.t)};
  }
  return best;
}
/** Numerical solver. User selects exact rail sequence; geometry-only diamond systems
 * provide an initial estimate; candidates are checked over the entire final leg.
 * Research box geometry only: not the native pocket/jaw solver.
 */
function searchBankRoute({start,target,rails,spin=0,speeds=[1.1,1.7,2.3,3],params=DEFAULT,angleSamples=721,tolerance=0.04}){
  const results=[];
  for(const speed of speeds){
    for(let i=0;i<angleSamples;i++){
      const angle=-Math.PI+2*Math.PI*i/(angleSamples-1);
      const trace=simulateRails(makeBall({x:start.x,z:start.z,vx:speed*Math.cos(angle),vz:speed*Math.sin(angle),wy:spin}),params,{maxEvents:rails.length,maxTime:20,sampleInterval:0.02,postFinalRailSeconds:10});
      if(trace.events.length<rails.length||trace.events.slice(0,rails.length).some((e,k)=>e.rail!==rails[k]))continue;
      const closest=finalLegClosest(trace,target,rails.length);
      if(closest&&closest.error<tolerance)results.push({angle,speed,spin,error:closest.error,closest,rails,trace});
    }
  }
  return results.sort((a,b)=>a.error-b.error);
}
function diamondToMeters(longitudinal,transverse,p=DEFAULT){return {x:(longitudinal/8-.5)*p.length,z:(.5-transverse/4)*p.width};}

return Object.freeze({DEFAULT,makeBall,railResponse,clothStep,simulateRails,finalLegClosest,searchBankRoute,diamondToMeters});
})();
const stroke = (() => {
/** Touch samples are timestamped seconds and distance in CSS pixels.
 * Use coalescedTouches on iOS; predicted touches ONLY for rendering, never impact.
 */
function analyzeStroke(samples,{pxPerMeter=1300,minSamples=3,maxSpeed=8}={}){
  const ordered=[...samples].filter(s=>Number.isFinite(s.t)&&Number.isFinite(s.x)&&Number.isFinite(s.y)).sort((a,b)=>a.t-b.t);
  if(ordered.length<minSamples)return {valid:false,reason:'insufficient samples'};
  const speeds=[];
  for(let i=1;i<ordered.length;i++){
    const a=ordered[i-1],b=ordered[i],dt=b.t-a.t;
    if(dt<=0)continue;
    speeds.push({t:b.t,vx:(b.x-a.x)/dt/pxPerMeter,vy:(b.y-a.y)/dt/pxPerMeter});
  }
  if(speeds.length<2)return {valid:false,reason:'invalid timestamps'};
  // Local median reduces isolated digitizer spikes without smoothing away acceleration.
  const v=speeds.map((s,i)=>{
    const win=speeds.slice(Math.max(0,i-1),Math.min(speeds.length,i+2)).map(q=>q.vy).sort((a,b)=>a-b);
    return win[Math.floor(win.length/2)];
  });
  const contact=Math.max(-maxSpeed,Math.min(maxSpeed,v.at(-1)));
  const peak=Math.max(...v.map(Math.abs));
  const end=speeds.at(-1),prev=speeds.at(-2);
  const acceleration=(v.at(-1)-v.at(-2))/Math.max(1e-4,end.t-prev.t);
  return {valid:true,contactSpeed:contact,peakSpeed:peak,acceleration, lateralDrift:ordered.at(-1).x-ordered[0].x,duration:ordered.at(-1).t-ordered[0].t};
}
function contactGate(previousTip,newTip,ballSurface){
  // only forward crossing triggers impact; finger-up is NOT an impact event.
  return previousTip<ballSurface&&newTip>=ballSurface;
}

return Object.freeze({analyzeStroke,contactGate});
})();
const elevated = (() => {
/** Zoker 3D Elevated Cue Prototype. SI units; y UP.
 * Isolated research engine: NOT yet calibrated, not integrated in iOS.
 * Original v0.2.1 CueStrike has no elevation or cue library.
 */
const STANDARD_BALL={mass:0.17,radius:0.028575,gravity:9.81};
const CUE_PRESETS=Object.freeze({
  zokerPlaying:{id:'zokerPlaying',kind:'playing',label:'Zoker Playing — illustrative',mass:0.54,tipHardness:0.55,stiffness:0.62,tipDiameter:0.0125,contactEfficiency:0.78,colors:['#633d27','#d6af77'],license:'original'},
  zokerJump:{id:'zokerJump',kind:'jump',label:'Zoker Jump — illustrative',mass:0.31,tipHardness:0.92,stiffness:0.94,tipDiameter:0.0138,contactEfficiency:0.88,colors:['#1b2630','#42b9cc'],license:'original'},
  zokerBreak:{id:'zokerBreak',kind:'break',label:'Zoker Break — illustrative',mass:0.56,tipHardness:0.85,stiffness:0.90,tipDiameter:0.0130,contactEfficiency:0.82,colors:['#222','#b6974d'],license:'original'}
});
const clamp=(v,a,b)=>Math.min(b,Math.max(a,v));
const cross=(a,b)=>({x:a.y*b.z-a.z*b.y,y:a.z*b.x-a.x*b.z,z:a.x*b.y-a.y*b.x});
const add=(a,b)=>({x:a.x+b.x,y:a.y+b.y,z:a.z+b.z});
const mul=(a,s)=>({x:a.x*s,y:a.y*s,z:a.z*s});
const dot=(a,b)=>a.x*b.x+a.y*b.y+a.z*b.z;
const norm=(v)=>{const l=Math.hypot(v.x,v.y,v.z);return l?mul(v,1/l):{x:0,y:0,z:0};};
function strike3D({cue=CUE_PRESETS.zokerPlaying, speed=2.5, azimuth=0,elevationDeg=0,tipSide=0,tipHeight=0,ball=STANDARD_BALL}={}){
  if(![speed,azimuth,elevationDeg,tipSide,tipHeight].every(Number.isFinite)||speed<0||speed>8||elevationDeg<0||elevationDeg>85)throw Error('invalid cue speed/elevation');
  const off=Math.hypot(tipSide,tipHeight);
  if(off>0.65)throw Error('tip outside testable contact patch / miscue risk');
  const elevation=elevationDeg*Math.PI/180;
  const d={x:Math.cos(azimuth)*Math.cos(elevation),y:-Math.sin(elevation),z:Math.sin(azimuth)*Math.cos(elevation)};
  const side={x:-Math.sin(azimuth),y:0,z:Math.cos(azimuth)};
  const up=norm(cross(side,d));
  const k=Math.sqrt(1-off*off);
  const r=mul(add(add(mul(d,-k),mul(side,tipSide)),mul(up,tipHeight)),ball.radius);
  // Simplified cue-ball effective-mass impulse. Efficiency is an uncalibrated stand-in
  // for compliance/contact loss; NOT a manufacturer rating or proof of jump height.
  const cueEffective=cue.mass*(0.35+0.35*cue.stiffness);
  const Jmag=cue.contactEfficiency*(1+0.35)*speed/(1/cueEffective+1/ball.mass);
  const impulse=mul(d,Jmag);
  const v=mul(impulse,1/ball.mass);
  const omega=mul(cross(r,impulse),1/(0.4*ball.mass*ball.radius**2));
  // A downward y impulse is applied. Ground response, not a fake vertical launch,
  // is what may create upward velocity in the first contact integration.
  return {position:{x:0,y:ball.radius,z:0},velocity:v,omega, cueId:cue.id, elevationDeg,impactImpulse:Jmag};
}
function stepFlightAndSlate(state,dt,{ball=STANDARD_BALL,slateRestitution=0.56,slateFriction=0.23,clothSlide=0.20,spinDamping=1.0}={}){
  if(dt<=0||dt>0.005)throw Error('dt should be 0 < dt <= 0.005');
  const s={...state,position:{...state.position},velocity:{...state.velocity},omega:{...state.omega}};
  const r=ball.radius,m=ball.mass,I=.4*m*r*r;
  const grounded=s.position.y<=r+1e-6 && s.velocity.y<=0;
  if(grounded){
    const contact={x:0,y:-r,z:0};
    const slip=add(s.velocity,cross(s.omega,contact));
    const u={x:slip.x,z:slip.z},mag=Math.hypot(u.x,u.z);
    if(mag>1e-7){
      const jMax=clothSlide*m*ball.gravity*dt;
      const j= Math.min(jMax,mag/(1/m+r*r/I));
      const jt={x:-j*u.x/mag,y:0,z:-j*u.z/mag};
      s.velocity=add(s.velocity,mul(jt,1/m));
      s.omega=add(s.omega,mul(cross(contact,jt),1/I));
    }else{
      const v=Math.hypot(s.velocity.x,s.velocity.z);
      const nv=Math.max(0,v-0.011*ball.gravity*dt);
      if(v){s.velocity.x*=nv/v;s.velocity.z*=nv/v;}
      s.omega.x=-s.velocity.z/r;s.omega.z=s.velocity.x/r;
    }
    s.omega.y*=Math.max(0,1-spinDamping*dt);
  }
  s.velocity.y-=ball.gravity*dt;
  s.position=add(s.position,mul(s.velocity,dt));
  let landed=false;
  if(s.position.y<r){
    s.position.y=r;
    if(s.velocity.y<0){
      const pre=s.velocity.y;
      // A rigid floor contact transfers DOWNWARD impact into a possible UPWARD rebound.
      s.velocity.y= -pre*slateRestitution;
      landed=true;
      // ground tangential impulse plus angular response
      const arm={x:0,y:-r,z:0};
      const slip=add(s.velocity,cross(s.omega,arm));
      const mag=Math.hypot(slip.x,slip.z);
      const jn=m*(s.velocity.y-pre);
      if(mag>1e-8){
        const jtMag=Math.min(slateFriction*jn,mag/(1/m+r*r/I));
        const jt={x:-jtMag*slip.x/mag,y:0,z:-jtMag*slip.z/mag};
        s.velocity=add(s.velocity,mul(jt,1/m));
        s.omega=add(s.omega,mul(cross(arm,jt),1/I));
      }
      if(s.velocity.y<0.045)s.velocity.y=0;
    }
  }
  return {state:s,landed};
}
function traceElevatedShot(config,options={}){
  const {dt=0.0005,duration=2,slateRestitution=0.56,slateFriction=0.23}=options;
  let s=strike3D(config),maxHeight=s.position.y,firstLandingTime=null,points=[];
  if(!Number.isFinite(dt)||dt<=0||dt>.005||!Number.isFinite(duration)||duration<=0||duration>5||dt<.0001)throw Error('invalid trace limits');
  points.push({t:0,...s.position});
  const total=Math.ceil(duration/dt),sampleEvery=Math.max(1,Math.floor(.005/dt));
  for(let i=0;i<total;i++){
    const prev=s.position.y;
    const result=stepFlightAndSlate(s,dt,{slateRestitution,slateFriction});
    s=result.state; maxHeight=Math.max(maxHeight,s.position.y);
    if(result.landed && firstLandingTime===null && prev>STANDARD_BALL.radius+1e-5)firstLandingTime=(i+1)*dt;
    if((i+1)%sampleEvery===0||i===total-1)points.push({t:(i+1)*dt,...s.position});
    if(!Number.isFinite(s.position.x+s.position.y+s.position.z))throw Error('nonfinite trajectory');
  }
  return {points,maxHeight,maxClearance:Math.max(0,maxHeight-STANDARD_BALL.radius),firstLandingTime,final:s};
}
/** Determine visible behaviour from actual trajectory, not from 'jump cue' label.
 * Elevated playing cues can hop; jump cues can also produce swerve.
 * Significant masse needs side spin and sliding-ground coupling after impact.
 */
function classifyShot({trajectory,tipSide=0,elevationDeg=0}){
  const clearance=trajectory.maxClearance;
  if(clearance>0.5*STANDARD_BALL.radius)return 'jump';
  if(elevationDeg>8&&Math.abs(tipSide)>0.1)return 'masse-candidate';
  return 'ordinary-or-hop';
}
/** Reference calibration: tune numerical parameters to observed outcomes.
 * Do not force outcomes to agree with diamond geometry at every speed.
 */
function compareReference(observed,predicted,weights={landingX:1,landingZ:1,height:1}){
  const dx=(observed.landingX??0)-(predicted.landingX??0);
  const dz=(observed.landingZ??0)-(predicted.landingZ??0);
  const dh=(observed.height??0)-(predicted.height??0);
  return weights.landingX*dx*dx+weights.landingZ*dz*dz+weights.height*dh*dh;
}

return Object.freeze({STANDARD_BALL,CUE_PRESETS,strike3D,stepFlightAndSlate,traceElevatedShot,classifyShot,compareReference});
})();
const golden = (() => {
/** ZUPE Golden Shots: deterministic fit+holdout for *measured* rail outcomes.
 * Use real units, and separate train from held-out validation. No magical path correction.
 * This calibration adjusts parameters rather than ball position.
 */
const { DEFAULT, makeBall, simulateRails } = bank;
const CANDIDATE_PARAMETERS = Object.freeze(['eRail','muRail','railSpeedSensitivity','muRoll']);
const bound = {eRail:[0.55,0.94],muRail:[0.02,0.45],railSpeedSensitivity:[0,0.08],muRoll:[0.003,0.025]};
function finite(x){return typeof x==='number'&&Number.isFinite(x);}
function validateGoldenShot(s){
 if(!s||typeof s.id!=='string'||!s.id||!['train','validation'].includes(s.partition))throw Error('id and partition required');
 if(!s.initial||!['x','z','vx','vz','wx','wy','wz'].every(k=>finite(s.initial[k]??(k==='wx'||k==='wy'||k==='wz'?0:undefined))))throw Error('initial condition incomplete');
 if(!Array.isArray(s.railSequence)||!s.railSequence.every(x=>['left','right','top','bottom'].includes(x)))throw Error('railSequence invalid');
 if(!s.observed||!Array.isArray(s.observed.contacts)||s.observed.contacts.length!==s.railSequence.length)throw Error('measured contacts required');
 if(!s.observed.contacts.every(p=>finite(p.x)&&finite(p.z)))throw Error('measured coordinates required');
 if(!finite(s.observed.uncertaintyMeters)||s.observed.uncertaintyMeters<=0)throw Error('measurement uncertainty required');
 if(!s.provenance||!s.provenance.method||!s.provenance.source)throw Error('provenance required');
 return true;
}
function predictReference(s,params=DEFAULT){
 validateGoldenShot(s);
 const result=simulateRails(makeBall(s.initial),params,{maxEvents:s.railSequence.length,maxTime:15,sampleInterval:.04});
 return {contacts:result.events.map(e=>({x:e.x,z:e.z,rail:e.rail,t:e.t})),events:result.events};
}
function shotLoss(s,params=DEFAULT){
 const pred=predictReference(s,params),truth=s.observed.contacts;
 if(pred.contacts.length!==truth.length||pred.contacts.some((p,i)=>p.rail!==s.railSequence[i]))return {loss:1e6,rmseMeters:Infinity,sequenceOK:false};
 const distances=truth.map((p,i)=>Math.hypot(p.x-pred.contacts[i].x,p.z-pred.contacts[i].z));
 const rmse=Math.sqrt(distances.reduce((sum,x)=>sum+x*x,0)/Math.max(1,distances.length));
 const uncertainty=s.observed.uncertaintyMeters;
 return {loss:distances.reduce((sum,d)=>sum+(d/uncertainty)**2,0)/Math.max(1,distances.length),rmseMeters:rmse,sequenceOK:true};
}
function evaluate(dataset,params=DEFAULT,partition='validation'){
 const samples=dataset.filter(s=>s.partition===partition);
 if(!samples.length)throw Error(`missing ${partition} data`);
 const r=samples.map(s=>({id:s.id,...shotLoss(s,params)}));
 return {count:r.length,sequencePass:r.filter(x=>x.sequenceOK).length,rmseMeters:r.every(x=>Number.isFinite(x.rmseMeters))?Math.sqrt(r.reduce((a,x)=>a+x.rmseMeters*x.rmseMeters,0)/r.length):null,normalizedLoss:r.reduce((a,x)=>a+x.loss,0)/r.length,shots:r};
}
function fitGolden(dataset,{iterations=5,initial=DEFAULT,keys=CANDIDATE_PARAMETERS}={}){
 dataset.forEach(validateGoldenShot);
 if(!dataset.some(s=>s.partition==='train'))throw Error('fit requires measured train data');
 if(!dataset.some(s=>s.partition==='validation'))throw Error('fit requires validation holdout');
 if(keys.some(k=>!bound[k]))throw Error('unsupported fit parameter');
 let params={...initial};
 const loss=(p)=>evaluate(dataset,p,'train').normalizedLoss;
 let current=loss(params);
 for(let cycle=0;cycle<iterations;cycle++){
  let improved=false;
  for(const key of keys){
   let best=params[key],bestLoss=current;
   const [lo,hi]=bound[key];
   const delta=(hi-lo)*0.13/2**cycle;
   for(const candidate of [Math.max(lo,params[key]-delta),Math.min(hi,params[key]+delta)]){
    const l=loss({...params,[key]:candidate});
    if(l+1e-12<bestLoss){best=candidate;bestLoss=l;}
   }
   if(bestLoss<current){params={...params,[key]:best};current=bestLoss;improved=true;}
  }
  if(!improved&&cycle===iterations-1)break;
 }
 return {parameters:params,training:evaluate(dataset,params,'train'),validation:evaluate(dataset,params,'validation'),warning:'Prototype rail-only fit, not evidence of real-world accuracy'};
}

return Object.freeze({CANDIDATE_PARAMETERS,validateGoldenShot,predictReference,shotLoss,evaluate,fitGolden});
})();
const equipment = (() => {
/** Equipment data without unlicensed logos or fake performance certification. */
const { CUE_PRESETS } = elevated;
const equipments=Object.freeze(Object.values(CUE_PRESETS).map(c=>Object.freeze({
 id:c.id,displayName:c.label,category:c.kind,appearance:{primary:c.colors[0],secondary:c.colors[1],logoAsset:null,meshAsset:null},
 parameters:{massKg:c.mass,tipDiameterM:c.tipDiameter,hardnessProxy:c.tipHardness,stiffnessProxy:c.stiffness,impactEfficiencyProxy:c.contactEfficiency},
 evidence:{massKg:'illustrative',tipDiameterM:'illustrative',hardnessProxy:'assumed',stiffnessProxy:'assumed',impactEfficiencyProxy:'assumed'},
 brandPermission:'original Zoker concept only',releaseStatus:'research prototype'
})));
function selectCue(id){const cue=equipments.find(c=>c.id===id);if(!cue)throw Error('unknown cue');return cue;}

return Object.freeze({equipments,selectCue});
})();
const recorder = (() => {
/** Recorder: export physics-authoritative frames for renderer/audio/replay.
 * Does not calculate alternate game-ball positions. */
function eventFrame(time,balls,contacts=[]){
 if(!Number.isFinite(time)||time<0)throw Error('bad timestamp');
 return Object.freeze({time,balls:balls.map(b=>({id:b.id??0,x:b.x??0,y:b.y??0,z:b.z??0,vx:b.vx??0,vy:b.vy??0,vz:b.vz??0,angularVelocity:b.angularVelocity??null})),contacts:contacts.map(x=>({...x}))});
}
function interpolateDisplay(a,b,time){
 if(!(a.time<=time&&time<=b.time)||b.time<=a.time)throw Error('invalid frame interval');
 const f=(time-a.time)/(b.time-a.time);
 return a.balls.map(x=>{const y=b.balls.find(z=>z.id===x.id);if(!y)throw Error('ball identity mismatch');return {id:x.id,x:x.x+(y.x-x.x)*f,y:x.y+(y.y-x.y)*f,z:x.z+(y.z-x.z)*f};});
}

return Object.freeze({eventFrame,interpolateDisplay});
})();
return Object.freeze({bank,stroke,elevated,golden,equipment,recorder});
})();