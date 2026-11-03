"""Compile the checked-in Premium Classic LITE kit into native asset datasets.
Source art is procedural; this is not the missing approved concept archive.
"""
from pathlib import Path
import json,subprocess,sys,hashlib,math,re,xml.etree.ElementTree as ET
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
KIT=ROOT.parents[1]/'DesignKits/ZokerPremiumClassic'
SOURCE=KIT/'out/Zoker_Premium_Classic_GitHub_Kit'
subprocess.run([sys.executable,str(KIT/'generate_github_kit.py')],check=True)
ASSETS=ROOT/'BankLab/Assets.xcassets'
manifest=[]
def dataset(name,filename,data):
 d=ASSETS/(name+'.dataset');d.mkdir(exist_ok=True)
 (d/filename).write_bytes(data)
 (d/'Contents.json').write_text(json.dumps({'data':[{'filename':filename,'idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
 manifest.append({'asset':name,'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)})
for material in sorted((SOURCE/'Materials/PBR').iterdir()):
 for image in sorted(material.glob('*.png')):dataset('PC_'+material.name+'_'+image.stem,'map.png',image.read_bytes())
for source,name in [('DesignSystem/Colors_And_Tokens.json','PC_Tokens'),('DesignSystem/HUD_Layout.json','PC_HUD'),('Geometry/WPA_9ft_DiamondLayout.json','PC_Diamonds'),('CueLibrary/CueFinishProfiles.json','PC_Cues')]:
 dataset(name,'data.json',(SOURCE/source).read_bytes())
# Convert authored OBJ cues to SceneKit's local +Y-tip convention. Each kit
# group is a surface of revolution (two rings); its authored radii and
# lengths are kept exactly, re-swept at 64 sides with closed butt/tip ends.
SIDES=64
for obj in sorted((SOURCE/'CueLibrary/OBJ').glob('*.obj')):
 points=[];groups={};order=[];material='Tip';group=''
 for line in obj.read_text().splitlines():
  parts=line.split()
  if not parts:continue
  if parts[0]=='v':points.append([float(parts[1]),float(parts[2]),float(parts[3])])
  if parts[0]=='g':group=parts[1]
  if parts[0]=='usemtl':material=parts[1]
  if parts[0]=='f':
   key=(group,material)
   if key not in groups:groups[key]=set();order.append(key)
   groups[key].update(int(x)-1 for x in parts[1:])
 rings=[]
 for key in order:
  material=key[1];by_y={}
  for i in groups[key]:
   x,y,z=points[i];by_y.setdefault(round(y,6),[]).append(math.hypot(x,z))
  (y0,r0),(y1,r1)=[(y,sum(v)/len(v)) for y,v in sorted(by_y.items())]
  rings.append((material,y0,r0,y1,r1))
 vertices=[];normals=[];uv=[];elements=[];names=[]
 def emit(material,indices):
  if material in names:elements[names.index(material)].extend(indices)
  else:names.append(material);elements.append(indices)
 for material,y0,r0,y1,r1 in rings:
  slope=(r0-r1)/max(y1-y0,1e-9);indices=[];base=len(vertices)//3
  for y,r in ((y0,r0),(y1,r1)):
   for k in range(SIDES+1):
    a=2*math.pi*k/SIDES;c,s_=math.cos(a),math.sin(a);n=[c,slope,s_];l=math.sqrt(sum(t*t for t in n))
    vertices+=[r*c,-y,r*s_];normals+=[c/l,-slope/l,s_/l];uv+=[k/SIDES,y]
  for k in range(SIDES):
   a,b=base+k,base+k+1;c_,d=a+SIDES+1,b+SIDES+1
   indices+=[a,b,c_,b,d,c_]
  emit(material,indices)
 # Flat end caps: butt (largest y) faces -Y in SceneKit space, tip faces +Y.
 for material,y,r,facing in ((rings[-1][0],rings[-1][3],rings[-1][4],-1.0),(rings[0][0],rings[0][1],rings[0][2],1.0)):
  centre=len(vertices)//3;vertices+=[0,-y,0];normals+=[0,facing,0];uv+=[.5,.5];indices=[]
  for k in range(SIDES+1):
   a=2*math.pi*k/SIDES;vertices+=[r*math.cos(a),-y,r*math.sin(a)];normals+=[0,facing,0];uv+=[.5+.5*math.cos(a),.5+.5*math.sin(a)]
  for k in range(SIDES):
   i,j=centre+1+k,centre+2+k
   indices+=[centre,i,j] if facing<0 else [centre,j,i]
  emit(material,indices)
 dataset('PC_Cue_'+obj.stem,'mesh.json',json.dumps(dict(vertices=[round(v,6) for v in vertices],normals=[round(v,5) for v in normals],uv=[round(v,5) for v in uv],elements=elements,names=names),separators=(',',':')).encode())
# The kit's bounded SVG command vocabulary: preserve the real icon paths.
S=8
for svg in sorted((SOURCE/'HUD/Icons/SVG').glob('*.svg')):
 im=Image.new('RGBA',(64*S,64*S));draw=ImageDraw.Draw(im);ink=(234,197,131,255);width=round(3.2*S)
 def line(points):
  p=[(round(x*S),round(y*S)) for x,y in points];draw.line(p,fill=ink,width=width,joint='curve')
  for x,y in [p[0],p[-1]]:draw.ellipse((x-width/2,y-width/2,x+width/2,y+width/2),fill=ink)
 for node in ET.fromstring(svg.read_text()).iter():
  tag=node.tag.split('}')[-1];a=node.attrib
  if tag=='circle':
   x,y,r=[float(a[k]) for k in ['cx','cy','r']];draw.ellipse(((x-r)*S,(y-r)*S,(x+r)*S,(y+r)*S),outline=ink,width=width)
  elif tag=='rect':
   x,y,w,h=[float(a[k]) for k in ['x','y','width','height']];draw.rounded_rectangle((x*S,y*S,(x+w)*S,(y+h)*S),radius=float(a.get('rx',0))*S,outline=ink,width=width)
  elif tag=='path':
   tokens=re.findall(r'[A-Za-z]|[-+]?(?:\d*\.\d+|\d+)',a['d']);i=0;cmd='';p=(0,0);start=p
   while i<len(tokens):
    if tokens[i].isalpha():cmd=tokens[i];i+=1
    op=cmd.upper();relative=cmd.islower()
    if op=='Z':line([p,start]);p=start;cmd='';continue
    count={'M':2,'L':2,'H':1,'V':1,'Q':4,'A':7}[op];args=list(map(float,tokens[i:i+count]));i+=count
    if op in ['M','L']:
     q=(args[0]+(p[0] if relative else 0),args[1]+(p[1] if relative else 0))
     if op=='L':line([p,q])
     else:start=q;cmd='l' if relative else 'L'
    elif op in ['H','V']:
     q=((p[0]+args[0] if relative else args[0]),p[1]) if op=='H' else (p[0],p[1]+args[0] if relative else args[0]);line([p,q])
    elif op=='Q':
     c=(args[0]+(p[0] if relative else 0),args[1]+(p[1] if relative else 0));q=(args[2]+(p[0] if relative else 0),args[3]+(p[1] if relative else 0))
     line([((1-t)**2*p[0]+2*(1-t)*t*c[0]+t*t*q[0],(1-t)**2*p[1]+2*(1-t)*t*c[1]+t*t*q[1]) for t in [j/32 for j in range(33)]])
    else:
     rx,ry,rotation,large,sweep,x,y=args;assert rotation==0 and rx==ry
     q=(x+(p[0] if relative else 0),y+(p[1] if relative else 0));dx=(p[0]-q[0])/2;dy=(p[1]-q[1])/2;r=max(rx,math.hypot(dx,dy));den=dx*dx+dy*dy
     factor=math.sqrt(max(0,(r*r-den)/max(den,1e-12)))*(-1 if large==sweep else 1)
     cx=(p[0]+q[0])/2+factor*dy;cy=(p[1]+q[1])/2-factor*dx
     begin=math.atan2(p[1]-cy,p[0]-cx);end=math.atan2(q[1]-cy,q[0]-cx);span=(end-begin)%(2*math.pi)
     if not sweep:span-=2*math.pi
     line([(cx+r*math.cos(begin+span*j/64),cy+r*math.sin(begin+span*j/64)) for j in range(65)])
    p=q
 import io
 buffer=io.BytesIO();im.resize((128,128),Image.Resampling.LANCZOS).save(buffer,format='PNG');dataset('PC_Icon_'+svg.stem,'icon.png',buffer.getvalue())
dataset('PC_Manifest','data.json',json.dumps(manifest,indent=2).encode())
print('PASS Premium Classic LITE:',len(manifest),'native assets; original concepts absent')
