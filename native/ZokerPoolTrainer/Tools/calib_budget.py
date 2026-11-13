"""Error budget: what a 240 fps iPhone overhead clip can measure. Monte Carlo with realistic noise."""
import numpy as np
rng=np.random.default_rng(1); g=9.81; R=0.028575; fps=240; dt=1/fps
SIG=0.0006      # centroid noise 0.6 mm (~0.6 px at 1 mm/px, motion blur + 100 Hz flicker)
SCALE=0.005     # 0.5 % homography scale error (systematic per clip)
N=400
def noisy(x,s):return x*(1+s)+rng.normal(0,SIG,x.shape)
out={}
# 1 rolling resistance: natural roll, v0 0.8 m/s, mu_r .010, fit 1.5 s
mu=.010;t=np.arange(0,1.5,dt);est=[]
for _ in range(N):
    s=rng.normal(0,SCALE);x=noisy(.8*t-.5*mu*g*t*t,s);c=np.polyfit(t,x,2);est.append(-2*c[0]/g)
out['mu_rolling (.010)']=np.std(est)
# 2 sliding: stun 2 m/s, mu_s .20, fit decel in slide phase (first 0.25 s, ends 0.29 s)
mu=.20;t=np.arange(0,.25,dt);est=[]
for _ in range(N):
    s=rng.normal(0,SCALE);x=noisy(2*t-.5*mu*g*t*t,s);c=np.polyfit(t,x,2);est.append(-2*c[0]/g)
out['mu_sliding (.20)']=np.std(est)
# 3 cushion: rebound speed from a 30 ms window just after contact (ball slides, decel mu_s g along v approx)
t=np.arange(dt,.03+dt/2,dt);est=[];ang=[]
for _ in range(N):
    s=rng.normal(0,SCALE);vx,vy=.82*.707,.6*.707
    x=noisy(vx*t,s);y=noisy(vy*t,s);cx=np.polyfit(t,x,2);cy=np.polyfit(t,y,2)
    est.append(np.hypot(cx[1],cy[1])/1.0);ang.append(np.degrees(np.arctan2(cy[1],cx[1])))
out['cushion speed ratio (per shot)']=np.std(est);out['cushion angle deg (per shot)']=np.std(ang)
# 4 throw: object-ball direction over 0.6 m vs centre line at contact.
# contact point from interpolated cue-ball track: lateral error of the line of centres
lat=[];dirn=[]
for _ in range(N):
    # cue ball lateral position at contact from a line fit over 40 frames before contact
    t=np.arange(-40,0)*dt;y=rng.normal(0,SIG,t.shape);c=np.polyfit(t,y,1);lat.append(c[1])
    tt=np.arange(1,120)*dt;yy=rng.normal(0,SIG,tt.shape);cc=np.polyfit(tt*1.2,yy,1);dirn.append(np.degrees(np.arctan(cc[0])))
cut_err=np.degrees(np.std(lat)/(2*R))
out['throw deg (per shot)']=np.hypot(cut_err,np.std(dirn))
# 4b ball-ball e from straight stun: cue ball residual speed = v(1-e)/2, v=1.5 m/s
t=np.arange(dt,.08,dt);est=[]
for _ in range(N):
    vr=1.5*(1-.94)/2;x=rng.normal(0,SIG,t.shape)+vr*t;c=np.polyfit(t,x,1);est.append(1-2*c[0]/1.5)
out['ball e (.94) per shot']=np.std(est)
# 5 spin decay from a marker: angle noise 6 deg, omega0 25 rad/s, decay 7 rad/s^2, fit 2 s of angle
t=np.arange(0,2,dt);est=[]
for _ in range(N):
    th=25*t-.5*7*t*t+np.radians(rng.normal(0,6,t.shape));c=np.polyfit(t,th,2);est.append(-2*c[0])
out['spin decay rad/s^2 (7)']=np.std(est)
# rolling shutter: readout ~4 ms over frame height; horizontal motion -> constant shear, vertical motion -> stretch
v=2.0;ro=.004;out['rolling-shutter bias if ball moves vertically in frame (mm)']=v*ro*1000*.03
for k,v in out.items():print(f'{k:58s} sigma = {v:.4g}')
print('pixel scale at 1.5 m height, 1x lens (~65 deg HFOV):',round(2*1.5*np.tan(np.radians(32.5))/1920*1000,2),'mm/px; ball =',round(2*R*1000/(2*1.5*np.tan(np.radians(32.5))/1920*1000)),'px')
