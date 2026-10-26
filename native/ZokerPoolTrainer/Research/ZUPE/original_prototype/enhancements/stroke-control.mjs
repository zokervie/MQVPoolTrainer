/** Touch samples are timestamped seconds and distance in CSS pixels.
 * Use coalescedTouches on iOS; predicted touches ONLY for rendering, never impact.
 */
export function analyzeStroke(samples,{pxPerMeter=1300,minSamples=3,maxSpeed=8}={}){
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
export function contactGate(previousTip,newTip,ballSurface){
  // only forward crossing triggers impact; finger-up is NOT an impact event.
  return previousTip<ballSurface&&newTip>=ballSurface;
}
