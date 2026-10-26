/** Equipment data without unlicensed logos or fake performance certification. */
import { CUE_PRESETS } from './elevated-cue-3d.mjs';
export const equipments=Object.freeze(Object.values(CUE_PRESETS).map(c=>Object.freeze({
 id:c.id,displayName:c.label,category:c.kind,appearance:{primary:c.colors[0],secondary:c.colors[1],logoAsset:null,meshAsset:null},
 parameters:{massKg:c.mass,tipDiameterM:c.tipDiameter,hardnessProxy:c.tipHardness,stiffnessProxy:c.stiffness,impactEfficiencyProxy:c.contactEfficiency},
 evidence:{massKg:'illustrative',tipDiameterM:'illustrative',hardnessProxy:'assumed',stiffnessProxy:'assumed',impactEfficiencyProxy:'assumed'},
 brandPermission:'original Zoker concept only',releaseStatus:'research prototype'
})));
export function selectCue(id){const cue=equipments.find(c=>c.id===id);if(!cue)throw Error('unknown cue');return cue;}
