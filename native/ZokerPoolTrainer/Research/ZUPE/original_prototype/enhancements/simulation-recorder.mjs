/** Recorder: export physics-authoritative frames for renderer/audio/replay.
 * Does not calculate alternate game-ball positions. */
export function eventFrame(time,balls,contacts=[]){
 if(!Number.isFinite(time)||time<0)throw Error('bad timestamp');
 return Object.freeze({time,balls:balls.map(b=>({id:b.id??0,x:b.x??0,y:b.y??0,z:b.z??0,vx:b.vx??0,vy:b.vy??0,vz:b.vz??0,angularVelocity:b.angularVelocity??null})),contacts:contacts.map(x=>({...x}))});
}
export function interpolateDisplay(a,b,time){
 if(!(a.time<=time&&time<=b.time)||b.time<=a.time)throw Error('invalid frame interval');
 const f=(time-a.time)/(b.time-a.time);
 return a.balls.map(x=>{const y=b.balls.find(z=>z.id===x.id);if(!y)throw Error('ball identity mismatch');return {id:x.id,x:x.x+(y.x-x.x)*f,y:x.y+(y.y-x.y)*f,z:x.z+(y.z-x.z)*f};});
}
