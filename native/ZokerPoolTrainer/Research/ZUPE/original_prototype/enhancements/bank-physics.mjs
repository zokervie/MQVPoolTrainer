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
  const vt=ball.vx*t.x+ball.vz*t.z + ball.wy*r;
  const e=clamp(p.eRail-p.railSpeedSensitivity*vn,0.4,0.95);
  const jn=-(1+e)*m*vn;
  const denom=1/m+r*r/I;
  const jt=clamp(-vt/denom,-p.muRail*Math.abs(jn),p.muRail*Math.abs(jn));
  ball.vx+=(jn*n.x+jt*t.x)/m;
  ball.vz+=(jn*n.z+jt*t.z)/m;
  // Spin coupling, sign follows contact-point velocity convention above.
  ball.wy+=r*jt/I;
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
export function simulateRails(initial,p=DEFAULT,{maxTime=25,maxEvents=4,sampleInterval=0.02}={}){
  const b={...initial}, events=[],points=[{t:0,x:b.x,z:b.z,wy:b.wy}];
  const halfX=p.length/2-p.radius,halfZ=p.width/2-p.radius;
  const count=Math.ceil(maxTime/p.dt);let lastSample=-Infinity;
  for(let i=0;i<count;i++){
    const old={...b};clothStep(b,p,p.dt);
    // Continuous interpolation of position over each time step; no tunneling.
    const collisions=[];
    if(b.x>halfX)collisions.push(['right',halfX]);
    if(b.x< -halfX)collisions.push(['left',-halfX]);
    if(b.z>halfZ)collisions.push(['bottom',halfZ]);
    if(b.z< -halfZ)collisions.push(['top',-halfZ]);
    for(const [rail,bound] of collisions){
      const axis=rail==='left'||rail==='right'?'x':'z';
      const den=b[axis]-old[axis];
      const fraction=den===0?1:clamp((bound-old[axis])/den,0,1);
      b.x=old.x+(b.x-old.x)*fraction;b.z=old.z+(b.z-old.z)*fraction;
      b[axis]=bound;
      const data=railResponse(b,RAILS[rail],p);
      if(data.hit)events.push({type:'rail',rail,t:(i+fraction)*p.dt,x:b.x,z:b.z,speed:Math.hypot(old.vx,old.vz),...data});
    }
    const t=(i+1)*p.dt;
    if(t-lastSample>=sampleInterval){points.push({t,x:b.x,z:b.z,wy:b.wy});lastSample=t;}
    if(events.length>=maxEvents)break;
    if(Math.hypot(b.vx,b.vz)<1e-4&&Math.abs(b.wy)<1e-3)break;
  }
  return {events,points,final:b,railCount:events.length};
}
/** Numerical solver. User selects exact rail sequence; geometry-only diamond systems
 * provide an initial estimate, but every candidate is simulated with spin/speed.
 */
export function searchBankRoute({start,target,rails,spin=0,speeds=[1.1,1.7,2.3,3],params=DEFAULT,angleSamples=721,tolerance=0.04}){
  const results=[];
  for(const speed of speeds){
    for(let i=0;i<angleSamples;i++){
      const angle=-Math.PI+2*Math.PI*i/(angleSamples-1);
      const trace=simulateRails(makeBall({x:start.x,z:start.z,vx:speed*Math.cos(angle),vz:speed*Math.sin(angle),wy:spin}),params,{maxEvents:rails.length,maxTime:20,sampleInterval:0.08});
      if(trace.events.length!==rails.length||trace.events.some((e,k)=>e.rail!==rails[k]))continue;
      const last=trace.points[trace.points.length-1];
      // Near final leg target: distance to segment connecting last 2 sampled points.
      const n=trace.points.length;const a=trace.points[Math.max(0,n-2)],b=last;
      const dx=b.x-a.x,dz=b.z-a.z,den=dx*dx+dz*dz;
      const t=den?clamp(((target.x-a.x)*dx+(target.z-a.z)*dz)/den,0,1):0;
      const error=Math.hypot(target.x-(a.x+t*dx),target.z-(a.z+t*dz));
      if(error<tolerance)results.push({angle,speed,spin,error,rails,trace});
    }
  }
  return results.sort((a,b)=>a.error-b.error);
}
export function diamondToMeters(longitudinal,transverse,p=DEFAULT){return {x:(longitudinal/8-.5)*p.length,z:(.5-transverse/4)*p.width};}
