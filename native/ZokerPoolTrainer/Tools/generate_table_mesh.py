"""Original APEX-reference proportions, not a manufacturer CAD model.
SciPy/NumPy are generation-only dependencies. Render mesh is bundled in the app.
Metres, +Y up. Regulation bed 2.54 x 1.27; outside 2.895 x 1.615.
"""
from pathlib import Path
import json,math
import numpy as np
from scipy.spatial import Delaunay
ROOT=Path(__file__).resolve().parents[1]
POCKETS=[(-.67,-1.305),(.67,-1.305),(-.706,0),(.706,0),(-.67,1.305),(.67,1.305)]
N=192
RADII=[.074,.074,.066,.066,.074,.074]

def mesh():return dict(vertices=[],normals=[],uv=[],indices=[])
def face(m,points,normals):
 base=len(m['vertices'])//3
 a,b,c=map(np.array,points[:3]);n=np.mean(normals,axis=0)
 if np.dot(np.cross(b-a,c-a),n)<0:points=list(reversed(points));normals=list(reversed(normals))
 for (x,y,z),n in zip(points,normals):
  m['vertices'] += [round(float(x),8),round(float(y),8),round(float(z),8)]
  m['normals'] += [round(float(k),8) for k in n]
  # World-space metres keep the textile density equal on all axes.
  m['uv'] += [round((x+.8075)/1.615,8),round((z+1.4475)/2.895,8)]
 m['indices'] += [base,base+1,base+2]
 if len(points)==4:m['indices'] += [base,base+2,base+3]

def bed():
 # Six disjoint, perfectly regular apertures; no boolean slivers or overlapping caps.
 rings=[[(cx+r*math.cos(2*math.pi*i/N),cz+r*math.sin(2*math.pi*i/N)) for i in range(N)] for (cx,cz),r in zip(POCKETS,RADII)]
 points=np.array([(-.79,-1.40),(.79,-1.40),(.79,1.40),(-.79,1.40)]+[p for ring in rings for p in ring])
 m=mesh();area=0
 for ids in Delaunay(points).simplices:
  tri=points[ids];centre=tri.mean(axis=0)
  if any(np.linalg.norm(centre-np.array(c))<r-1e-7 for c,r in zip(POCKETS,RADII)):continue
  # Since ring chords are Delaunay edges, no retained triangle may intrude into an aperture.
  for (cx,cz),radius in zip(POCKETS,RADII):
   p=np.array([cx,cz]);v=tri-p
   for a,b in zip(v,np.roll(v,-1,axis=0)):
    d=b-a;t=np.clip(-np.dot(a,d)/np.dot(d,d),0,1)
    # Circle chords lie at r*cos(pi/N), not r; tolerance is the polygon sagitta.
    assert np.linalg.norm(a+t*d)>=radius*math.cos(math.pi/N)-2e-7
  u,v=tri[1]-tri[0],tri[2]-tri[0]
  area+=abs(float(u[0]*v[1]-u[1]*v[0]))/2
  face(m,[(x,0,z) for x,z in tri],[[0,1,0]]*3)
 expected=1.58*2.8-sum(N*r*r*math.sin(2*math.pi/N)/2 for r in RADII)
 assert abs(area-expected)<1e-7,(area,expected)
 for ring,(cx,cz) in zip(rings,POCKETS):
  for a,b in zip(ring,ring[1:]+ring[:1]):
   # Explicit inward wall normals on each circular aperture.
   v=np.array([cx-(a[0]+b[0])/2,cz-(a[1]+b[1])/2]);v/=np.linalg.norm(v)
   face(m,[(a[0],0,a[1]),(b[0],0,b[1]),(b[0],-.027,b[1]),(a[0],-.027,a[1])],[[v[0],0,v[1]]]*4)
 return m

def rounded_radius(a,inset=0):
 dx,dz=math.cos(a),math.sin(a);lo,hi=0,2
 bx,bz=.8075-inset,1.4475-inset;r=max(.001,.065-inset)
 for _ in range(48):
  t=(lo+hi)/2;qx,qz=abs(t*dx)-(bx-r),abs(t*dz)-(bz-r)
  sdf=math.hypot(max(qx,0),max(qz,0))+min(max(qx,qz),0)-r
  if sdf>0:hi=t
  else:lo=t
 return (lo+hi)/2

def opening_radius(a):
 d=np.array([math.cos(a),math.sin(a)])
 rect=min(.687/max(abs(d[0]),1e-14),1.322/max(abs(d[1]),1e-14));value=rect
 for centre,radius in zip(POCKETS,RADII):
  c=np.array(centre);proj=float(c@d);disc=proj*proj-float(c@c)+(radius+.007)**2
  if disc<0:continue
  near,far=proj-math.sqrt(disc),proj+math.sqrt(disc)
  if near>rect or far<0:continue
  # Smooth only the join of the circular pocket cut and the inner rail opening.
  h=max(0,min(1,.5+.5*(value-far)/.003))
  value=far+(value-far)*h+.003*h*(1-h)
 return value

def annulus(inner,outer,top,bottom):
 m=mesh();count=2048
 a=[2*math.pi*i/count for i in range(count)]
 inn=[(inner(t)*math.cos(t),inner(t)*math.sin(t)) for t in a]
 out=[(outer(t)*math.cos(t),outer(t)*math.sin(t)) for t in a]
 for i in range(count):
  j=(i+1)%count;u,v=inn[i],inn[j];b,c=out[i],out[j]
  face(m,[(u[0],top,u[1]),(b[0],top,b[1]),(c[0],top,c[1]),(v[0],top,v[1])],[[0,1,0]]*4)
  for contour,inward in [(out,False),(inn,True)]:
   p,q=contour[i],contour[j];dx,dz=q[0]-p[0],q[1]-p[1];length=math.hypot(dx,dz)
   n=[dz/length,0,-dx/length]
   if inward:n=[-n[0],0,-n[2]]
   face(m,[(p[0],top,p[1]),(q[0],top,q[1]),(q[0],bottom,q[1]),(p[0],bottom,p[1])],[n]*4)
 return m
def deck_region():
 # Exact boundary of rectangle UNION six disjoint circular pocket cuts.
 # The union is not star-shaped at corner pockets: radial strips can bridge a hole.
 from matplotlib.path import Path as PolygonPath
 X,Z=.687,1.322
 corners=[(-X,-Z),(X,-Z),(X,Z),(-X,Z)]
 pieces=[];intersections=[[] for _ in POCKETS]
 for side,(a,b) in enumerate(zip(corners,corners[1:]+corners[:1])):
  a=np.array(a);b=np.array(b);d=b-a;length=np.linalg.norm(d);cuts=[(0.,a),(1.,b)]
  for index,(centre,r) in enumerate(zip(POCKETS,RADII)):
   centre=np.array(centre);radius=r+.007;v=a-centre
   A=float(d@d);B=2*float(v@d);C=float(v@v)-radius*radius;disc=B*B-4*A*C
   if disc<0:continue
   for t in [(-B-math.sqrt(disc))/(2*A),(-B+math.sqrt(disc))/(2*A)]:
    if 0<t<1:
     point=a+t*d;cuts.append((t,point));angle=math.atan2(point[1]-centre[1],point[0]-centre[0])%(2*math.pi)
     intersections[index].append((angle,point))
  cuts.sort(key=lambda x:x[0])
  for (t,a),(u,b) in zip(cuts,cuts[1:]):
   centre=(a+b)/2
   if any(np.linalg.norm(centre-np.array(c))<r+.007-1e-9 for c,r in zip(POCKETS,RADII)):continue
   steps=max(1,math.ceil(np.linalg.norm(b-a)/.008))
   pieces.append([a+(b-a)*k/steps for k in range(steps+1)])
 for c,r,entries in zip(POCKETS,RADII,intersections):
  assert len(entries)==2,(c,entries)
  entries.sort(key=lambda v:v[0]);radius=r+.007
  for k in range(2):
   start,a=entries[k];end,b=entries[(k+1)%2]
   if end<start:end+=2*math.pi
   mid=(start+end)/2;point=np.array(c)+radius*np.array([math.cos(mid),math.sin(mid)])
   if abs(point[0])<X and abs(point[1])<Z:continue
   steps=max(2,math.ceil((end-start)*256/(2*math.pi)))
   arc=[np.array(c)+radius*np.array([math.cos(start+(end-start)*j/steps),math.sin(start+(end-start)*j/steps)]) for j in range(steps+1)]
   arc[0]=a;arc[-1]=b;pieces.append(arc)
 def key(p):return tuple(round(float(x),7) for x in p)
 starts={key(piece[0]):piece for piece in pieces};inner=[];piece=pieces[0];first=key(piece[0])
 for _ in range(len(pieces)+1):
  inner.extend(piece[:-1]);end=key(piece[-1])
  if end==first:break
  piece=starts[end]
 assert end==first and len(inner)>100
 outer=[(rounded_radius(a)*math.cos(a),rounded_radius(a)*math.sin(a)) for a in np.linspace(0,2*math.pi,768,endpoint=False)]
 points=np.array(outer+inner);triangles=Delaunay(points).simplices
 centres=points[triangles].mean(axis=1)
 keep=PolygonPath(outer).contains_points(centres)&~PolygonPath(inner).contains_points(centres)
 triangles=triangles[keep];edges={}
 for tri in triangles:
  for a,b in zip(tri,np.roll(tri,-1)):edge=tuple(sorted((int(a),int(b))));edges[edge]=edges.get(edge,0)+1
 for offset,ring in [(0,outer),(len(outer),inner)]:
  for i in range(len(ring)):
   edge=tuple(sorted((offset+i,offset+(i+1)%len(ring))))
   if edges.get(edge)!=1:
    # Qhull may omit collinear points. A longer boundary edge must cover the exact segment.
    p,q=points[list(edge)];covered=False
    for (ai,bi),count in edges.items():
     if count!=1:continue
     a,b=points[ai],points[bi];d=b-a;length2=float(d@d)
     if length2<1e-16:continue
     crossp=abs(float(d[0]*(p-a)[1]-d[1]*(p-a)[0]))
     crossq=abs(float(d[0]*(q-a)[1]-d[1]*(q-a)[0]))
     if max(crossp,crossq)<1e-10 and min(float((p-a)@d),float((q-a)@d))>=-1e-10 and max(float((p-a)@d),float((q-a)@d))<=length2+1e-10:
      covered=True;break
    assert covered,('Missing constrained edge',edge)
 def area(ring):
  a=np.array(ring);b=np.roll(a,-1,axis=0);return abs(float(np.sum(a[:,0]*b[:,1]-a[:,1]*b[:,0])))/2
 m=mesh();total=0
 for ids in triangles:
  tri=points[ids];u,v=tri[1]-tri[0],tri[2]-tri[0];total+=abs(float(u[0]*v[1]-u[1]*v[0]))/2
  face(m,[(x,.056,z) for x,z in tri],[[0,1,0]]*3)
 assert abs(total-(area(outer)-area(inner)))<1e-8
 for ring,inward in [(outer,False),(inner,True)]:
  for p,q in zip(ring,ring[1:]+ring[:1]):
   dx,dz=q[0]-p[0],q[1]-p[1];length=math.hypot(dx,dz);n=[dz/length,0,-dx/length]
   if inward:n=[-n[0],0,-n[2]]
   face(m,[(p[0],.056,p[1]),(q[0],.056,q[1]),(q[0],-.025,q[1]),(p[0],-.025,p[1])],[n]*4)
 return m
meshes={'bed':bed(),'deck':deck_region(),
        'trim':annulus(lambda a:rounded_radius(a,.005),rounded_radius,.058,.054)}
p=ROOT/'BankLab/Assets.xcassets/TableMesh.dataset'
(p/'mesh.json').write_text(json.dumps(meshes,separators=(',',':')))
print('PASS: six regular apertures, exact bed/deck area, constrained boundary edges, no deck triangle bridges a pocket')
print({k:len(v['vertices'])//3 for k,v in meshes.items()})
