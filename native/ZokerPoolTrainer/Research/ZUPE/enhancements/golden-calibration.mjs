/** ZUPE Golden Shots: deterministic fit+holdout for *measured* rail outcomes.
 * Use real units, and separate train from held-out validation. No magical path correction.
 * This calibration adjusts parameters rather than ball position.
 */
import { DEFAULT, makeBall, simulateRails } from './bank-physics.mjs';
export const CANDIDATE_PARAMETERS = Object.freeze(['eRail','muRail','railSpeedSensitivity','muRoll']);
const bound = {eRail:[0.55,0.94],muRail:[0.02,0.45],railSpeedSensitivity:[0,0.08],muRoll:[0.003,0.025]};
function finite(x){return typeof x==='number'&&Number.isFinite(x);}
export function validateGoldenShot(s){
 if(!s||typeof s.id!=='string'||!s.id||!['train','validation'].includes(s.partition))throw Error('id and partition required');
 if(!s.initial||!['x','z','vx','vz','wx','wy','wz'].every(k=>finite(s.initial[k]??(k==='wx'||k==='wy'||k==='wz'?0:undefined))))throw Error('initial condition incomplete');
 if(!Array.isArray(s.railSequence)||!s.railSequence.every(x=>['left','right','top','bottom'].includes(x)))throw Error('railSequence invalid');
 if(!s.observed||!Array.isArray(s.observed.contacts)||s.observed.contacts.length!==s.railSequence.length)throw Error('measured contacts required');
 if(!s.observed.contacts.every(p=>finite(p.x)&&finite(p.z)))throw Error('measured coordinates required');
 if(!finite(s.observed.uncertaintyMeters)||s.observed.uncertaintyMeters<=0)throw Error('measurement uncertainty required');
 if(!s.provenance||!s.provenance.method||!s.provenance.source)throw Error('provenance required');
 return true;
}
export function predictReference(s,params=DEFAULT){
 validateGoldenShot(s);
 const result=simulateRails(makeBall(s.initial),params,{maxEvents:s.railSequence.length,maxTime:15,sampleInterval:.04});
 return {contacts:result.events.map(e=>({x:e.x,z:e.z,rail:e.rail,t:e.t})),events:result.events};
}
export function shotLoss(s,params=DEFAULT){
 const pred=predictReference(s,params),truth=s.observed.contacts;
 if(pred.contacts.length!==truth.length||pred.contacts.some((p,i)=>p.rail!==s.railSequence[i]))return {loss:1e6,rmseMeters:Infinity,sequenceOK:false};
 const distances=truth.map((p,i)=>Math.hypot(p.x-pred.contacts[i].x,p.z-pred.contacts[i].z));
 const rmse=Math.sqrt(distances.reduce((sum,x)=>sum+x*x,0)/Math.max(1,distances.length));
 const uncertainty=s.observed.uncertaintyMeters;
 return {loss:distances.reduce((sum,d)=>sum+(d/uncertainty)**2,0)/Math.max(1,distances.length),rmseMeters:rmse,sequenceOK:true};
}
export function evaluate(dataset,params=DEFAULT,partition='validation'){
 const samples=dataset.filter(s=>s.partition===partition);
 if(!samples.length)throw Error(`missing ${partition} data`);
 const r=samples.map(s=>({id:s.id,...shotLoss(s,params)}));
 return {count:r.length,sequencePass:r.filter(x=>x.sequenceOK).length,rmseMeters:r.every(x=>Number.isFinite(x.rmseMeters))?Math.sqrt(r.reduce((a,x)=>a+x.rmseMeters*x.rmseMeters,0)/r.length):null,normalizedLoss:r.reduce((a,x)=>a+x.loss,0)/r.length,shots:r};
}
export function fitGolden(dataset,{iterations=5,initial=DEFAULT,keys=CANDIDATE_PARAMETERS}={}){
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
