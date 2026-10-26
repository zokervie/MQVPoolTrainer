"""Validate the shipped material bytes without Pillow or any extra package."""
from pathlib import Path
import hashlib,json,struct,zlib
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'Tools/materials-manifest.json').read_text())
for item in manifest:
 p=root/item['path'];data=p.read_bytes()
 if hashlib.sha256(data).hexdigest()!=item['sha256']:raise SystemExit('Material checksum mismatch: '+str(p))
 if len(data)!=item['bytes'] or data[:8]!=b'\x89PNG\r\n\x1a\n':raise SystemExit('Invalid PNG: '+str(p))
 pos=8;ended=False
 while pos<len(data):
  if pos+12>len(data):raise SystemExit('Truncated PNG chunk: '+str(p))
  n=struct.unpack('>I',data[pos:pos+4])[0];kind=data[pos+4:pos+8]
  block=data[pos+4:pos+8+n];crc=data[pos+8+n:pos+12+n]
  if len(crc)!=4 or zlib.crc32(block)&0xffffffff!=struct.unpack('>I',crc)[0]:raise SystemExit('Corrupt PNG chunk: '+str(p))
  if kind==b'IHDR':
   w,h=struct.unpack('>II',data[pos+8:pos+16])
   if [w,h]!=item['pixels']:raise SystemExit('Wrong dimensions: '+str(p))
  pos+=n+12
  if kind==b'IEND':ended=True;break
 if not ended:raise SystemExit('Missing PNG end: '+str(p))
print('PASS: '+str(len(manifest))+' material maps, SHA-256, PNG chunk CRCs and dimensions')
