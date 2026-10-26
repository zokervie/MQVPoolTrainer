/** Zoker Bank Physics Research Module - independent from game render loop.
 * SI units. This is a testable planar ball/rail model, NOT a verified replacement
 * for the project's full solver. Integration uses existing pocket/jaw geometry.
 */
export const DEFAULT = Object.freeze({
  length:2.54,width:1.27,radius:0.028575,mass:0.17,
  gravity:9.81,muSlide:0.20,muRoll:0.011,spinDecel:10,
  eRail:0.82,muRail:0.20,railSpeedSensitivity:0.025,
  railHeight:0.0365, dt:1/2000
});
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const dot=(a,b)=>a.x*b.x+a.z*b.z;
const len=v=>Math.hypot(v.x,v.z);
const normal=v=>{const n=len(v);return n?{x:v.x/n,z:v.z/n}:{x:0,z:0}};
export function makeBall({x=0,z=0,vx=0,vz=0,wx=0,wy=0,wz=0}={}) {return {x,z,vx,vz,wx,wy,wz};}
export function railResponse(ball, outward, p=DEFAULT){
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
export function clothStep(b,p=DEFAULT,dt=p.dt){
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
export function simulateRails(initial,p=DEFAULT,{maxTime=25,maxEvents=4,sampleInterval=0.02,postFinalRailSeconds=0}={}){
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
export function finalLegClosest(trace,target,railCount){
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
export function searchBankRoute({start,target,rails,spin=0,speeds=[1.1,1.7,2.3,3],params=DEFAULT,angleSamples=721,tolerance=0.04}){
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
export function diamondToMeters(longitudinal,transverse,p=DEFAULT){return {x:(longitudinal/8-.5)*p.length,z:(.5-transverse/4)*p.width};}
