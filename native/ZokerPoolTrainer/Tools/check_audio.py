"""Verify bundled real-recording bytes and licence provenance, not perceived fidelity."""
import base64,hashlib,json,wave,io
from pathlib import Path
root=Path(__file__).resolve().parents[1]
items=json.loads((root/'Tools/AudioSources/manifest.json').read_text())
assert len(items)==7
for item in items:
 data=base64.b64decode((root/'Tools/AudioSources'/(item['asset']+'.wav.b64')).read_text())
 assert hashlib.sha256(data).hexdigest()==item['sha256']
 target=root/'BankLab/Assets.xcassets'/(item['asset']+'.dataset')/'audio.wav'
 assert target.read_bytes()==data
 assert item['license'] in ('CC0-1.0','CC-BY-3.0') and item['source'].startswith('https://freesound.org/')
 with wave.open(io.BytesIO(data)) as f:
  assert f.getnchannels()==1 and f.getsampwidth()==2 and f.getframerate()==44100
  assert f.getnframes()==item['frames'] and f.getnframes()>4000
print('PASS: seven real pool recordings; encoded/bundled bytes, PCM headers, source/attribution manifests')
