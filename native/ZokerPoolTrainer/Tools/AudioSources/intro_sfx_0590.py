"""Zokervie intro SFX, 3.2 s, procedural (own asset). Recipes adapted from the Web Audio
synth in the owner's Gemini HTML draft, retimed to the 0.59 intro timeline."""
import numpy as np, wave, sys
from scipy.signal import butter, sosfilt
SR=48000; DUR=3.2; N=int(SR*DUR)
out=np.zeros(N)
t_all=np.arange(N)/SR
def expramp(a,b,n): return a*(b/a)**(np.arange(n)/max(1,n-1))
def osc(kind,f):
    ph=2*np.pi*np.cumsum(f)/SR
    if kind=='sine': return np.sin(ph)
    if kind=='tri': return 2/np.pi*np.arcsin(np.sin(ph))
    if kind=='saw': return 2*((ph/(2*np.pi))%1)-1
def env_ad(n,att,peak,decay_to=1e-4):
    e=np.empty(n); a=max(1,int(att*SR)); a=min(a,n)
    e[:a]=np.linspace(1e-4,peak,a); e[a:]=expramp(peak,decay_to,n-a) if n>a else []
    return e
def put(sig,t0):
    i=int(t0*SR); j=min(N,i+len(sig)); out[i:j]+=sig[:j-i]
def sweep_bp(x,f0,f1,q,block=256):
    y=np.zeros_like(x); n=len(x); fs=expramp(f0,f1,(n+block-1)//block)
    zi=None
    for k,fc in enumerate(fs):
        bw=fc/q; lo=max(20,fc-bw/2); hi=min(SR/2-100,fc+bw/2)
        sos=butter(2,[lo,hi],btype='band',fs=SR,output='sos')
        seg=x[k*block:(k+1)*block]
        if zi is None: zi=np.zeros((sos.shape[0],2))
        yy,zi=sosfilt(sos,seg,zi=zi); y[k*block:k*block+len(seg)]=yy
    return y
rng=np.random.default_rng(7)
# 0.05 low thump
n=int(.3*SR); put(osc('sine',np.concatenate([expramp(95,36,int(.18*SR)),np.full(n-int(.18*SR),36)]))*env_ad(n,.018,.6),0.05)
# 0.30-0.85 riser
d=.55; n=int((d+.05)*SR)
f=np.concatenate([expramp(85,420,int(d*SR)),np.full(n-int(d*SR),420)]); fs=np.concatenate([expramp(42,98,int(d*SR)),np.full(n-int(d*SR),98)])
x=sweep_bp(osc('saw',f)+osc('sine',fs),180,1650,3.2)
g=np.concatenate([np.linspace(1e-3,.28,int(d*.85*SR)),expramp(.28,1e-3,n-int(d*.85*SR))]); put(x*g*2.2,0.30)
# 0.85 impact: boom + clack + snap noise + reverse whoosh
T=0.85
n=int(.85*SR); put(osc('sine',np.concatenate([expramp(135,28,int(.75*SR)),np.full(n-int(.75*SR),28)]))*env_ad(n,.008,.95),T)
n=int(.06*SR); put(osc('tri',expramp(1680,420,n))*env_ad(n,.002,.75,8e-4),T)
n=int(.08*SR); nz=rng.uniform(-1,1,n)*np.exp(-np.arange(n)/(n*.22))
put(sosfilt(butter(2,[2200-440,2200+440],btype='band',fs=SR,output='sos'),nz)*.65*3,T)
n=int(.6*SR); rv=rng.uniform(-1,1,n)*(np.arange(n)/n)**2.2
gr=np.concatenate([np.linspace(1e-3,.36,int(n*.92)),expramp(.36,1e-3,n-int(n*.92))]); put(sweep_bp(rv,260,1900,1.8)*gr*2.5,T+.14)
# lock-in clicks while shards assemble
for k,tc in enumerate([1.05,1.25,1.45,1.65,1.85]):
    m=.92+k*.08; n=int(.06*SR); put(osc('sine',expramp(1180*m,340*m,n))*env_ad(n,.003,.26,8e-4),tc)
# 1.90 reveal: drop + chime + warm pad
R=1.90; n=int(1.25*SR); put(osc('sine',expramp(110,31,n))*env_ad(n,.015,.85),R)
for i,fq in enumerate([880,1318.5,1760,2637]):
    n=int(1.85*SR); put(osc('sine' if i%2==0 else 'tri',np.full(n,fq))*env_ad(n,.02,.09/(i*.45+1)),R+i*.045)
pad=osc('sine',np.full(N,55))+osc('tri',np.full(N,110.25)); pad=sosfilt(butter(2,240,fs=SR,output='sos'),pad)
pg=np.clip((t_all-R)/1.0,0,1)*.14; out+=pad*pg
# soft fade out last 0.15 s, normalise to -1 dBFS
fo=int(.15*SR); out[-fo:]*=np.linspace(1,0,fo)
out*=10**(-1/20)/np.max(np.abs(out))
st=np.stack([out,out],1)
with wave.open(sys.argv[1],'wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((st*32767).astype('<i2').tobytes())
print('peak dBFS', 20*np.log10(np.max(np.abs(out))), 'rms dBFS', 20*np.log10(np.sqrt(np.mean(out**2))))
