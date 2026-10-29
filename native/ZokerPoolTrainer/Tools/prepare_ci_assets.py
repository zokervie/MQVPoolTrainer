"""Regenerate omitted large original assets on CI; no art is downloaded externally."""
from pathlib import Path
import hashlib,json,struct,subprocess,sys,base64,io
from PIL import Image
root=Path(__file__).resolve().parents[1]
assets=root/'BankLab/Assets.xcassets'
maps=['ClothAlbedo','ClothNormal','ClothRoughness','WalnutAlbedo','WalnutNormal','WalnutRoughness','LeatherNormal']
if any(not (assets/(name+'.dataset')/'map.png').is_file() for name in maps):
 subprocess.run([sys.executable,str(root/'Tools/generate_materials.py')],check=True)
if not (assets/'TableMesh.dataset/mesh.json').is_file():
 subprocess.run([sys.executable,str(root/'Tools/generate_table_mesh.py')],check=True)
manifest=[]
for name in sorted(maps):
 p=assets/(name+'.dataset')/'map.png';data=p.read_bytes();w,h=struct.unpack('>II',data[16:24])
 manifest.append({'path':str(p.relative_to(root)),'pixels':[w,h],'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
(root/'Tools/materials-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
icons=assets/'AppIcon.appiconset';entries=json.loads((icons/'Contents.json').read_text())['images']
missing=[entry for entry in entries if not (icons/entry['filename']).exists()]
if missing:
 source=io.BytesIO(base64.b64decode((root/'Tools/ci-icon.png.b64').read_text()))
 with Image.open(source) as image:
  for entry in missing:
   size=round(float(entry['size'].split('x')[0])*float(entry['scale'][:-1]))
   image.convert('RGB').resize((size,size),Image.Resampling.LANCZOS).save(icons/entry['filename'])
print('Prepared generated material/mesh assets and local repository app icon sizes.')


# Real pool audio is versioned as base64 for connector-safe transport; verify every decoded byte.
audio_root=root/'Tools/AudioSources'
for item in json.loads((audio_root/'manifest.json').read_text()):
 data=base64.b64decode((audio_root/(item['asset']+'.wav.b64')).read_text(),validate=False)
 assert hashlib.sha256(data).hexdigest()==item['sha256'],item['asset']
 target=assets/(item['asset']+'.dataset')/'audio.wav'
 target.write_bytes(data)
print('Prepared seven attributed field-recording pool samples.')
