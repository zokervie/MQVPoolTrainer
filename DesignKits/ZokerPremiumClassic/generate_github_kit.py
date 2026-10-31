#!/usr/bin/env python3
"""Reproducible Zoker Premium Classic MATERIALS + HUD + CUE source package.
No third-party Python dependencies. These are PROCEDURAL ASSETS, not original AI
concept previews or validated production meshes. Do not touch physics.
"""
from pathlib import Path
from math import sin, cos, pi
import json, struct, zlib, zipfile, hashlib, csv, io, shutil
BASE=Path(__file__).resolve().parent
ROOT=BASE/"out"/"Zoker_Premium_Classic_GitHub_Kit"
if ROOT.exists():shutil.rmtree(ROOT)
ROOT.mkdir(parents=True)
def put(n,c):
 p=ROOT/n;p.parent.mkdir(parents=True,exist_ok=True)
 if isinstance(c,str):p.write_text(c,encoding="utf-8")
 else:p.write_bytes(c)
 return p
def js(n,v):return put(n,json.dumps(v,indent=2,ensure_ascii=False)+"\n")
def chunk(k,b):return struct.pack(">I",len(b))+k+b+struct.pack(">I",zlib.crc32(k+b)&0xffffffff)
def png(w,h,channels,fn):
 buf=bytearray()
 for y in range(h):
  buf.append(0)
  for x in range(w):buf.extend(fn(x,y))
 return b"\x89PNG\r\n\x1a\n"+chunk(b'IHDR',struct.pack(">IIBBBBB",w,h,8,2 if channels==3 else 0,0,0,0))+chunk(b'IDAT',zlib.compress(bytes(buf),6))+chunk(b'IEND',b'')
def noise(x,y,seed):
 n=(x*374761393+y*668265263+seed*2246822519)&0xffffffff
 n=((n^(n>>13))*1274126177)&0xffffffff
 return ((n^(n>>16))&65535)/32767.5-1
mats={
 "FeltEmerald":((18,105,93),"cloth",.93,0),
 "WalnutDark":((72,38,21),"wood",.42,0),
 "PocketLeather":((28,23,22),"leather",.84,0),
 "ChampagneGold":((182,139,76),"metal",.27,.83),
 "CueMaple":((198,151,91),"wood",.36,0),
 "CueCarbon":((33,37,39),"carbon",.48,.02),
 "CueEbony":((33,22,17),"wood",.29,0),
 "CueWrapBlack":((25,24,27),"leather",.88,0)}
catalog={}
for index,(name,(color,kind,rough,metal)) in enumerate(mats.items()):
 def field(x,y):
  n=noise(x,y,index+1)
  if kind=="wood":return .42*sin(y*.12+sin(x*.027)*4)+.19*sin(y*.53+sin(x*.016)*2)+.1*n
  if kind=="carbon":return .31*sin((x+y)*.6)*sin((x-y)*.6)+.11*n
  if kind=="cloth":return .10*sin(x*.91+y*.27)+.13*n
  if kind=="leather":return .14*sin(x*.33)*sin(y*.31)+.18*n
  return .08*sin(y*.48)+.04*n
 def f(mode):
  def pixel(x,y):
   a=field(x,y)
   if mode=="albedo":return tuple(max(0,min(255,int(c*(1+a*.23)))) for c in color)
   if mode=="normal":
    dx=(field(x+1,y)-field(x-1,y))*.18;dy=(field(x,y+1)-field(x,y-1))*.18
    return max(0,min(255,int(128-dx*110))),max(0,min(255,int(128-dy*110))),250
   if mode=="roughness":return (max(0,min(255,int((rough+a*.07)*255))),)
   return (int(metal*255),)
  return pixel
 catalog[name]={}
 for mapname in ("albedo","normal","roughness","metallic"):
  path=f"Materials/PBR/{name}/{mapname}.png"
  put(path,png(512,512,3 if mapname in ("albedo","normal") else 1,f(mapname)))
  catalog[name][mapname]=path
 catalog[name].update({"roughness_target":rough,"metallic_target":metal,"texture_pixels":512})
js("Materials/material_catalog.json",catalog)
# Standard 9-ft pool sights: 12 on long rails + 6 on short rails.
sites=[]
for side,rail in [(-1,"left"),(1,"right")]:
 for z in (-952.5,-635,-317.5,317.5,635,952.5):
  sites.append(dict(rail=rail,x_mm=side*(635+93.6625),z_mm=z))
for side,rail in [(-1,"foot"),(1,"head")]:
 for x in (-317.5,0,317.5):
  sites.append(dict(rail=rail,x_mm=x,z_mm=side*(1270+93.6625)))
assert len(sites)==18
js("Geometry/WPA_9ft_DiamondLayout.json",dict(playing_mm=[1270,2540],spacing_mm=317.5,offset_from_cushion_nose_mm=93.6625,sites=sites,visual_only=True))
f=io.StringIO();writer=csv.DictWriter(f,fieldnames=("rail","x_mm","z_mm"));writer.writeheader();writer.writerows(sites)
put("Geometry/diamond_positions.csv",f.getvalue())
icons={
 "Coach":"<path d='M8 23 32 11 56 23 32 35z M19 32v10q13 12 26 0V32 M56 23v22'/>",
 "Camera":"<rect x='9' y='18' width='46' height='31' rx='5'/><path d='m18 18 5-8h17l5 8'/><circle cx='32' cy='34' r='10'/>",
 "Tools":"<path d='M13 12 52 51M40 13 14 40'/>",
 "Replay":"<path d='M14 18a22 22 0 1 1-4 17M14 5v14H1M27 23l15 9-15 9z'/>",
 "Undo":"<path d='M23 12 10 25l13 13M11 25h25a17 17 0 0 1 0 34'/>",
 "Spin":"<circle cx='32' cy='32' r='23'/><path d='M32 6v52M6 32h52'/><circle cx='32' cy='32' r='5'/>",
 "Elevation":"<path d='M17 57V7M47 57V7M12 8h10M12 32h10M12 56h10M39 56V10l8-3 7 47z'/>",
 "Diamond":"<path d='m32 5 22 27-22 27L10 32z'/>",
 "Cue":"<path d='M8 55 54 9M44 7l13 13'/>",
 "Balls":"<circle cx='25' cy='25' r='18'/><circle cx='42' cy='38' r='18'/>",
 "Menu":"<path d='M9 16h46M9 32h46M9 48h46'/>",
 "Settings":"<circle cx='32' cy='32' r='10'/><path d='M32 4v13M32 47v13M4 32h13M47 32h13'/>",
 "Play":"<path d='m23 12 27 20-27 20z'/>"}
for name,path in icons.items():
 put(f"HUD/Icons/SVG/{name}.svg",f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><g fill="none" stroke="#EAC583" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round">{path}</g></svg>')
js("DesignSystem/HUD_Layout.json",dict(orientation="landscape",left_from_top=["Coach","B"],B_position="bottom_left",H="hidden",right_from_top=["Camera","Dụng cụ","Replay","Lùi cú"],bottom_right=["Effect","Elevation_right_of_effect"],coach="drills_only",min_touch_target_pt=44))
js("DesignSystem/Colors_And_Tokens.json",dict(felt="#12695D",walnut="#482615",gold="#EAC583",ink="#131218",fps_target_not_measured=60))
roles={"p3":"play","air":"jump","bk":"break","svb":"play","propel":"jump","breach":"break","ec9":"play","ad3":"jump","pbg":"break","zplay":"play","zjump":"jump","zbreak":"break"}
profiles=[]
for name,role in roles.items():
 length=1.06 if role=="jump" else 1.45
 segments=[("tip",0,.008,.006,.006,"Tip"),("ferrule",.008,.024,.006,.006,"Ferrule"),("shaft",.024,length*.58,.006,.010,"Carbon" if name not in ("ec9","zplay","zjump","zbreak") else "Maple"),("joint",length*.58,length*.60,.010,.011,"Gold"),("forearm",length*.60,length*.77,.011,.013,"Ebony"),("wrap",length*.77,length*.94,.013,.014,"Wrap"),("butt",length*.94,length*.992,.014,.015,"Ebony"),("cap",length*.992,length,.015,.015,"Gold")]
 verts=[];faces=[];start=1
 for group,a,b,r1,r2,mat in segments:
  if b<=a:continue
  for yy,rad in ((a,r1),(b,r2)):
   for k in range(24):
    ang=2*pi*k/24;verts.append(f"v {rad*cos(ang):.6f} {yy:.6f} {rad*sin(ang):.6f}")
  faces.extend([f"g {group}",f"usemtl {mat}"])
  for k in range(24):
   i,j=start+k,start+(k+1)%24
   faces.extend((f"f {i} {j} {j+24}",f"f {i} {j+24} {i+24}"))
  start+=48
 put(f"CueLibrary/OBJ/{name}.obj","\n".join([f"mtllib {name}.mtl",f"o {name}"]+verts+faces)+"\n")
 put(f"CueLibrary/OBJ/{name}.mtl","newmtl Tip\nKd .04 .22 .40\nnewmtl Ferrule\nKd .86 .84 .73\nnewmtl Carbon\nKd .12 .16 .18\nnewmtl Maple\nKd .73 .49 .29\nnewmtl Gold\nKd .82 .61 .27\nnewmtl Ebony\nKd .11 .075 .06\nnewmtl Wrap\nKd .1 .1 .1\n")
 profiles.append(dict(id=name,role=role,obj=f"CueLibrary/OBJ/{name}.obj",render_only=True))
js("CueLibrary/CueFinishProfiles.json",profiles)
put("00_READ_ME_FIRST_VI.md","""# Zoker Premium Classic — GitHub generated LITE kit

Generated from source in this branch. Includes 32 PBR maps in PNG (512px), 13 SVG icons, 12 OBJ/MTL taper cue models, 18 WPA 9-ft sight locations and safe-area HUD layout. Original 21MB concept ZIP and AI preview pictures are not part of this smaller reproducible release.
B is LOWER LEFT, Coach ABOVE B, no H on HUD. Right: Camera / Dung cu / Replay / Lui cu. Elevation RIGHT of Effect. Coach for drills only.
Source assets are visual-only, not manufacturer-measured meshes or physics. Do not change solver; no IPA in this asset kit.
""")
put("CODEX_PROMPT_VI.md","""Codex: repo zokervie/MQVPoolTrainer, branch ci/native-0.19-workflow. Run python3 DesignKits/ZokerPremiumClassic/generate_github_kit.py. Integrate the generated asset materials with SceneKit physically based materials, use HUD_Layout.json, 18 diamond markers, and 12 cue IDs. Keep B in lower-left with Coach above, hide H; right controls Camera/Tools/Replay/Undo and bottom-right Effect+Elevation. Do not touch or retune C++ solver merely for visuals. Keep legacy data and 20 table choices. Enable balanced/high graphics with thermal fallback, verify no black table/clipping, real screenshot QA (Aim/Top/Overview), test UI and 60fps target on actual iPhone if available. Report source SHA, exact tests and IPA signing/build status. No fabricated evidence.
""")
manifest={}
for p in sorted(ROOT.rglob("*")):
 if p.is_file():manifest[str(p.relative_to(ROOT))]=hashlib.sha256(p.read_bytes()).hexdigest()
js("MANIFEST_SHA256.json",manifest)
zipfile_path=BASE/"Zoker_Premium_Classic_GitHub_Kit.zip"
with zipfile.ZipFile(zipfile_path,"w",zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in sorted(ROOT.rglob("*")):
  if p.is_file():z.write(p,arcname=str(p.relative_to(ROOT.parent)))
print(f"ASSET_KIT_READY: {zipfile_path.name}, {zipfile_path.stat().st_size} bytes, {len(manifest)} files")
