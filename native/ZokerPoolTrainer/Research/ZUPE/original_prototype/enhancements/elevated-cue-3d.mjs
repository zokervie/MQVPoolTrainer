/** Zoker 3D Elevated Cue Prototype. SI units; y UP.
 * Isolated research engine: NOT yet calibrated, not integrated in iOS.
 * Original v0.2.1 CueStrike has no elevation or cue library.
 */
export const STANDARD_BALL={mass:0.17,radius:0.028575,gravity:9.81};
export const CUE_PRESETS=Object.freeze({
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
export function strike3D({cue=CUE_PRESETS.zokerPlaying, speed=2.5, azimuth=0,elevationDeg=0,tipSide=0,tipHeight=0,ball=STANDARD_BALL}={}){
  if(speed<0||elevationDeg<0||elevationDeg>85)throw Error('invalid cue speed/elevation');
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
export function stepFlightAndSlate(state,dt,{ball=STANDARD_BALL,slateRestitution=0.56,slateFriction=0.23,clothSlide=0.20,spinDamping=1.0}={}){
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
export function traceElevatedShot(config,options={}){
  const {dt=0.0005,duration=2,slateRestitution=0.56,slateFriction=0.23}=options;
  let s=strike3D(config),maxHeight=s.position.y,firstLandingTime=null,points=[];
  const total=Math.ceil(duration/dt),sampleEvery=Math.max(1,Math.floor(.005/dt));
  for(let i=0;i<total;i++){
    const prev=s.position.y;
    const result=stepFlightAndSlate(s,dt,{slateRestitution,slateFriction});
    s=result.state; maxHeight=Math.max(maxHeight,s.position.y);
    if(result.landed && firstLandingTime===null && prev>STANDARD_BALL.radius+1e-5)firstLandingTime=(i+1)*dt;
    if(i%sampleEvery===0)points.push({t:i*dt,...s.position});
    if(!Number.isFinite(s.position.x+s.position.y+s.position.z))throw Error('nonfinite trajectory');
  }
  return {points,maxHeight,maxClearance:Math.max(0,maxHeight-STANDARD_BALL.radius),firstLandingTime,final:s};
}
/** Determine visible behaviour from actual trajectory, not from 'jump cue' label.
 * Elevated playing cues can hop; jump cues can also produce swerve.
 * Significant masse needs side spin and sliding-ground coupling after impact.
 */
export function classifyShot({trajectory,tipSide=0,elevationDeg=0}){
  const clearance=trajectory.maxClearance;
  if(clearance>0.5*STANDARD_BALL.radius)return 'jump';
  if(elevationDeg>8&&Math.abs(tipSide)>0.1)return 'masse-candidate';
  return 'ordinary-or-hop';
}
/** Reference calibration: tune numerical parameters to observed outcomes.
 * Do not force outcomes to agree with diamond geometry at every speed.
 */
export function compareReference(observed,predicted,weights={landingX:1,landingZ:1,height:1}){
  const dx=(observed.landingX??0)-(predicted.landingX??0);
  const dz=(observed.landingZ??0)-(predicted.landingZ??0);
  const dh=(observed.height??0)-(predicted.height??0);
  return weights.landingX*dx*dx+weights.landingZ*dz*dz+weights.height*dh*dh;
}
