"""Original tileable material maps. NumPy/Pillow are build-time tools only.
Every exported map is bound to a rendered material; no size padding assets.
"""
from pathlib import Path
import json,io,os
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]/'BankLab/Assets.xcassets'
rng=np.random.default_rng(20261016)
def save(name,a):
 d=ROOT/(name+'.dataset');d.mkdir(exist_ok=True)
 image=Image.fromarray(np.uint8(np.clip(a,0,255)))
 buffer=io.BytesIO();image.save(buffer,format='PNG',compress_level=6)
 with (d/'map.tmp').open('wb') as f:
  f.write(buffer.getvalue());f.flush();os.fsync(f.fileno())
 (d/'map.tmp').replace(d/'map.png')
 with Image.open(d/'map.png') as check:check.load()
 (d/'Contents.json').write_text(json.dumps({'data':[{'filename':'map.png','idiom':'universal'}], 'info':{'author':'xcode','version':1}}))
 print(name,round((d/'map.png').stat().st_size/1e6,2),'MB',flush=True)
def normal(height,strength):
 dx=(np.roll(height,-1,1)-np.roll(height,1,1))*strength
 dy=(np.roll(height,-1,0)-np.roll(height,1,0))*strength
 nz=np.ones_like(dx);norm=np.sqrt(dx*dx+dy*dy+1)
 return np.stack([(1-dx/norm)*127.5,(1-dy/norm)*127.5,(1+nz/norm)*127.5],axis=2)
# Aperiodic, isotropic microfibres: no sinusoidal warp/weft grid at grazing angles.
n=4096
noise=rng.normal(0,1,(n,n)).astype(np.float32)
height=(noise+np.roll(noise,1,0)+np.roll(noise,-1,0)+np.roll(noise,1,1)+np.roll(noise,-1,1))/5
# Correlated random fibres with a subtle nap; no regular stripe frequencies.
nap=sum(np.roll(noise,k,axis=0) for k in range(12))/12
height=height*.65+nap*.35
fiber=height*11.0
color=np.stack([224+fiber,224+fiber,224+fiber],axis=2)
save('ClothAlbedo',color)
save('ClothNormal',normal(height,.32))
small=height.reshape(2048,2,2048,2).mean(axis=(1,3))
save('ClothRoughness',237+small*8)
del noise,height,fiber,color,small,nap
# Walnut with longitudinal pores and gently curved growth grain.
rng=np.random.default_rng(42)
n=2048
y,x=np.mgrid[:n,:n].astype(np.float32)
phase=x*.11+3*np.sin(y*2*np.pi/n)+1.4*np.sin(y*6*np.pi/n+x*.006)
grain=np.sin(phase)+.4*np.sin(phase*3.0)
pores=rng.normal(0,1,(n,n)).astype(np.float32)
pores=(pores+np.roll(pores,1,0)+np.roll(pores,2,0))/2
h=grain*.5+pores*.35
save('WalnutAlbedo',np.stack([66+grain*11+pores*3,39+grain*7+pores*2,25+grain*4+pores*1.5],axis=2))
save('WalnutNormal',normal(h,.22))
save('WalnutRoughness',102+grain*12+pores*8)
# Leather pores for pocket liners, which remain below the cloth surface.
h=rng.normal(0,1,(1024,1024)).astype(np.float32)
h=(h+np.roll(h,1,0)+np.roll(h,1,1))/2
save('LeatherNormal',normal(h,.5))
print('All maps generated.',flush=True)
