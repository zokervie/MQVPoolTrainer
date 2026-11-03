from pathlib import Path
import hashlib,json,re
from PIL import Image
root=Path(__file__).resolve().parents[1];assets=root/'BankLab/Assets.xcassets'
manifest=json.loads((assets/'PC_Manifest.dataset/data.json').read_text())
for item in manifest:
 directory=assets/(item['asset']+'.dataset');index=json.loads((directory/'Contents.json').read_text());data=(directory/index['data'][0]['filename']).read_bytes()
 assert hashlib.sha256(data).hexdigest()==item['sha256'] and len(data)==item['bytes'],item['asset']
images=list(assets.glob('PC_*_albedo.dataset/map.png'));assert len(images)==8
for path in assets.glob('PC_*.dataset/*.png'):
 with Image.open(path) as im:im.verify()
layout=json.loads((assets/'PC_Diamonds.dataset/data.json').read_text());assert len(layout['sites'])==18
for item in layout['sites']:
 assert abs(abs(item['x_mm'])-728.6625)<1e-7 or abs(abs(item['z_mm'])-1363.6625)<1e-7
cues=list(assets.glob('PC_Cue_*.dataset/mesh.json'));assert len(cues)==12
for path in cues:
 m=json.loads(path.read_text());assert len(m['normals'])==len(m['vertices']);assert len(m['elements'])==len(m['names']);assert all(len(t)%3==0 for t in m['elements'])
source=(root/'BankLab/UI/EquipmentLibrary.swift').read_text();tables=source[source.index('static let all:[TableLook]'):source.index('struct CueLook')];assert len(re.findall(r'\.init\(id:',tables))==20
print('PASS Premium Classic LITE:',len(manifest),'checksummed native assets, 18 sights, 12 cue meshes, 20 retained table choices; concept matching NOT VERIFIED')
