# Zokervie intro C "Cú đánh hai băng" - animated, 6.0 s. Blender 4.5 LTS, built by script.
# Blender -b -P zokervie_intro_c.py -- --out DIR [--w 960 --h 540] [--samples 16] [--fps 30] [--frames a-b] [--video --wav PATH] [--font TTF]
# Geometry note: the Z is an exact mirror-reflection two-cushion path between the two long rails;
# the table is turned 22.5 deg in frame so legs 1 and 3 are horizontal and leg 2 runs at 45 deg.
import bpy, bmesh, math, random, sys, os
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(n, d=None): return argv[argv.index(n) + 1] if n in argv else d
OUT = arg("--out", "/tmp/zkvc"); FONT = arg("--font")
W, H, SAMPLES = int(arg("--w", "1280")), int(arg("--h", "720")), int(arg("--samples", "64"))
FPS = int(arg("--fps", "30")); T = 6.0; NF = int(round(T * FPS)); FR = arg("--frames"); VIDEO = "--video" in argv; WAV = arg("--wav"); SUB = "--sub" in argv
if WAV: WAV = os.path.abspath(WAV)   # v3: a relative path gave a silent track
os.makedirs(OUT, exist_ok=True); random.seed(7)

S, CX, CY, D = 0.01, 502.0, 500.0, 0.28
F = -0.60; BR = 74.0; NOTCH = 96.0; R = BR * S; BZ = F + R
def P(x, y, z=0.0): return Vector(((x - CX) * S, -(y - CY) * S, z))
S1, E1, NB = P(182, 312, BZ), P(656, 312, BZ), P(244, 724, BZ)          # logo-scale path
K = 5.85                                                                # table path = logo skeleton x K (real ball/table ratio)
def big(p): return Vector((p.x * K, p.y * K, BZ))
S1w, E1w, NBw = big(S1), big(E1), big(NB)
A = math.radians(22.5); Vn = Vector((math.cos(A), math.sin(A), 0)); Un = Vector((-math.sin(A), math.cos(A), 0))
HALF_W, HALF_L = 16.5, 33.0
N1 = E1w + Vn * R; N2 = NBw - Vn * R; M = (N1 + N2) / 2; M.z = 0          # rail noses and table centre

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"; cy = sc.cycles; cy.device = "CPU"; cy.samples = SAMPLES; cy.use_denoising = True
try: cy.denoiser = "OPENIMAGEDENOISE"
except Exception: pass
cy.max_bounces = 6; cy.glossy_bounces = 4; cy.diffuse_bounces = 2
sc.render.resolution_x, sc.render.resolution_y = W, H; sc.render.image_settings.file_format = "PNG"
try: sc.view_settings.view_transform = "AgX"; sc.view_settings.look = "AgX - Medium High Contrast"
except Exception: pass
world = bpy.data.worlds.new("W"); sc.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.002, 0.003, 0.006, 1)

def srgb(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(((x + .055) / 1.055) ** 2.4 if x > .04045 else x / 12.92 for x in c) + (1,)
def principled(name, **kw):
    m = bpy.data.materials.new(name); m.use_nodes = True; b = m.node_tree.nodes["Principled BSDF"]
    for k, v in kw.items():
        if k in b.inputs: b.inputs[k].default_value = v
    return m
def noise_to(m, socket, scale, lo, hi, axis=(1, 1, 1), detail=6):
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord"); mp = nt.nodes.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = axis
    nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = scale; nz.inputs["Detail"].default_value = detail
    mr = nt.nodes.new("ShaderNodeMapRange"); mr.inputs["To Min"].default_value = lo; mr.inputs["To Max"].default_value = hi
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"]); nt.links.new(mp.outputs["Vector"], nz.inputs["Vector"])
    nt.links.new(nz.outputs["Fac"], mr.inputs["Value"])
    if socket: nt.links.new(mr.outputs["Result"], b.inputs[socket])
    return nt, b, mr
def emissive(name, color, strength):
    m = bpy.data.materials.new(name); m.use_nodes = True; n = m.node_tree.nodes; n.clear()
    e = n.new("ShaderNodeEmission"); e.inputs[0].default_value = color; e.inputs[1].default_value = strength
    o = n.new("ShaderNodeOutputMaterial"); m.node_tree.links.new(e.outputs[0], o.inputs[0]); return m, e

GOLD = principled("Gold", **{"Base Color": srgb("#E0AA45"), "Metallic": 1.0, "Roughness": .24})
noise_to(GOLD, "Roughness", 40, .2, .3)
IVORY = principled("Ivory", **{"Base Color": srgb("#F6EEDC"), "Roughness": .1, "Coat Weight": 1, "Coat Roughness": .03})
FERRULE = principled("Ferrule", **{"Base Color": srgb("#F3EEE4"), "Roughness": .35})
CHALK = principled("Tip", **{"Base Color": srgb("#3F6F9F"), "Roughness": .95})
MAPLE = principled("Maple", **{"Base Color": srgb("#E6CF9F"), "Roughness": .28, "Coat Weight": .7, "Coat Roughness": .08})
nt, b, mr = noise_to(MAPLE, None, 3, 0, 1, (1.5, 1.5, 40))
rp = nt.nodes.new("ShaderNodeValToRGB"); rp.color_ramp.elements[0].color = srgb("#D9BD86"); rp.color_ramp.elements[1].color = srgb("#EFDCB4")
nt.links.new(mr.outputs["Result"], rp.inputs["Fac"]); nt.links.new(rp.outputs["Color"], b.inputs["Base Color"])
EBONY = principled("Ebony", **{"Base Color": srgb("#17110E"), "Roughness": .22, "Coat Weight": 1, "Coat Roughness": .05})
STEEL = principled("Joint", **{"Base Color": srgb("#C9C2B4"), "Metallic": 1, "Roughness": .22})
def felt_mat(name, col):
    m = principled(name, **{"Base Color": srgb(col), "Roughness": 1.0, "Sheen Weight": .3, "Sheen Tint": srgb("#4A6A9A")})
    nt = m.node_tree; bf = nt.nodes["Principled BSDF"]; nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 900
    bp = nt.nodes.new("ShaderNodeBump"); bp.inputs["Strength"].default_value = .15
    nt.links.new(nz.outputs["Fac"], bp.inputs["Height"]); nt.links.new(bp.outputs["Normal"], bf.inputs["Normal"]); return m
FELT = felt_mat("Felt", "#0C1A33"); FELTL = felt_mat("FeltLogo", "#0A1426")
WOOD = principled("Walnut", **{"Base Color": srgb("#2A1810"), "Roughness": .3, "Coat Weight": .8, "Coat Roughness": .08})
nt, b, mr = noise_to(WOOD, None, 2.2, 0, 1, (6, .25, 6))
rp = nt.nodes.new("ShaderNodeValToRGB"); rp.color_ramp.elements[0].color = srgb("#1C0F09"); rp.color_ramp.elements[1].color = srgb("#3B2416")
nt.links.new(mr.outputs["Result"], rp.inputs["Fac"]); nt.links.new(rp.outputs["Color"], b.inputs["Base Color"])
FLOOR = principled("Floor", **{"Base Color": (.012, .009, .007, 1), "Roughness": .45})

def link(o): sc.collection.objects.link(o); return o
TABLE, LOGO = [], []

# ---------- table (carom-style, no pockets in frame) ----------
tbl = link(bpy.data.objects.new("Table", None)); tbl.location = M; tbl.rotation_euler = (0, 0, A); TABLE.append(tbl)
def profile(name, prof, L, mat, bevel=0):
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    f = bm.faces.new([bm.verts.new((d, -L / 2, F + z)) for d, z in prof])
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, vec=Vector((0, L, 0)), verts=[e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
    o = link(bpy.data.objects.new(name, me)); o.data.materials.append(mat)
    if bevel: bv = o.modifiers.new("b", "BEVEL"); bv.width = bevel; bv.segments = 3; bv.limit_method = "ANGLE"
    return o
CUSH = [(0, .85), (0, .97), (1.1, 1.12), (1.1, -.05), (.55, -.05)]
RAIL = [(1.1, 1.12), (4.3, 1.12), (4.3, -1.8), (1.1, -1.8)]
def diamond(parent, d, y):
    me = bpy.data.meshes.new("dia"); bm = bmesh.new()
    bm.faces.new([bm.verts.new(v) for v in ((d - .17, y, F + 1.125), (d, y - .3, F + 1.125), (d + .17, y, F + 1.125), (d, y + .3, F + 1.125))])
    bm.to_mesh(me); bm.free(); o = link(bpy.data.objects.new("dia", me)); o.data.materials.append(IVORY); o.parent = parent; TABLE.append(o)
for loc, rot, L, n in (((HALF_W, 0), 0, 2 * HALF_L + 8.6, 8), ((-HALF_W, 0), math.pi, 2 * HALF_L + 8.6, 8),
                       ((0, HALF_L), math.pi / 2, 2 * HALF_W + 2.2, 4), ((0, -HALF_L), -math.pi / 2, 2 * HALF_W + 2.2, 4)):
    side = link(bpy.data.objects.new("Side", None)); side.parent = tbl; side.location = (loc[0], loc[1], 0); side.rotation_euler = (0, 0, rot); TABLE.append(side)
    for o in (profile("Cushion", CUSH, L, FELT), profile("Rail", RAIL, L, WOOD, .06)): o.parent = side; TABLE.append(o)
    span = 2 * HALF_L if n == 8 else 2 * HALF_W
    for i in range(1, n): diamond(side, 2.7, -span / 2 + span * i / n)
bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, F)); bed = bpy.context.object; bed.scale = (2 * HALF_W + 2.4, 2 * HALF_L + 2.4, 1)
bed.data.materials.append(FELT); bed.parent = tbl; TABLE.append(bed)
bpy.ops.mesh.primitive_plane_add(size=600, location=(0, 0, F - 20)); floor = bpy.context.object; floor.data.materials.append(FLOOR); TABLE.append(floor)

# ---------- ball + playing cue ----------
bpy.ops.mesh.primitive_uv_sphere_add(segments=96, ring_count=48, radius=R, location=S1w)
ball = bpy.context.object; ball.data.materials.append(IVORY); bpy.ops.object.shade_smooth()
rcue = link(bpy.data.objects.new("RealCue", None)); rcue.rotation_euler = (0, math.radians(-6), math.radians(180)); TABLE.append(rcue)
bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=.17); tipd = bpy.context.object
tipd.scale = (.45, 1, 1); tipd.location = (.08, 0, 0); tipd.parent = rcue; tipd.data.materials.append(CHALK); bpy.ops.object.shade_smooth(); TABLE.append(tipd)
for s0, s1, r0, r1, m in ((.06, .28, 17, 17, CHALK), (.28, .95, 17, 17.5, FERRULE), (.95, 13.0, 17.5, 25, MAPLE), (13.0, 13.25, 25.5, 25.5, STEEL), (13.25, 30, 26, 39, EBONY)):
    bpy.ops.mesh.primitive_cone_add(vertices=64, radius1=r0 / 100, radius2=r1 / 100, depth=s1 - s0)
    o = bpy.context.object; o.data.materials.append(m); bpy.ops.object.shade_smooth()
    o.rotation_euler = (0, math.radians(90), 0); o.location = ((s0 + s1) / 2, 0, 0); o.parent = rcue; TABLE.append(o)
rcue.location = S1w + Vector((-R, 0, 0))

def specks(name, centre, count, mat, size, spread, bias):
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    for _ in range(count):
        d = Vector((random.gauss(0, 1), random.gauss(0, 1), random.gauss(0, 1))) + bias
        if d.length < 1e-4: continue
        p = centre + d.normalized() * spread * random.random() ** 1.6
        if p.z < F + .01: p.z = F + .01 + random.random() * .05
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=size * random.uniform(.35, 1.0), matrix=Matrix.Translation(p - centre))
    bm.to_mesh(me); bm.free(); o = link(bpy.data.objects.new(name, me)); o.data.materials.append(mat); o.location = centre; TABLE.append(o); return o
DUST = principled("ChalkDust", **{"Base Color": srgb("#7FAEE6"), "Roughness": 1, "Emission Color": srgb("#7FAEE6"), "Emission Strength": .08})
dust = specks("dust", S1w + Vector((-R - .05, 0, 0)), 1700, DUST, .0075, 1.35, Vector((-.9, 0, .7)))
SPK, _ = emissive("Spark", srgb("#FFD98A"), 40)
sparks = specks("sparks", E1w + Vn * (R * .8) + Vector((0, 0, -.2)), 90, SPK, .07, 2.6, -Vn * 1.4 + Vector((0, 0, .5)))
sparks2 = specks("sparks2", NBw - Vn * (R * .8) + Vector((0, 0, -.2)), 110, SPK, .07, 2.8, Vn * 1.4 + Vector((0, 0, .5)))

TR_MAT, TR_EM = emissive("Trail", srgb("#FFCF6E"), 16)
def trail(name, a, b, frac=1.0, depth=.15, group=TABLE):
    cu = bpy.data.curves.new(name, "CURVE"); cu.dimensions = "3D"; sp = cu.splines.new("POLY"); sp.points.add(1)
    for i, p in enumerate((a, b)): sp.points[i].co = (p.x, p.y, F + .01, 1)
    cu.bevel_depth = depth; cu.bevel_resolution = 3; cu.bevel_factor_mapping_end = "SPLINE"; cu.bevel_factor_end = frac
    o = link(bpy.data.objects.new(name, cu)); o.data.materials.append(TR_MAT); group.append(o); return o
D3 = (E1w - S1w).normalized()
s3 = (N1 - NBw).dot(Vn) / D3.dot(Vn) - 1.6 * R; L3 = min(33.8, s3); print("ZKV_L3", round(s3, 2), round(L3, 2))
tr1 = trail("Trail1", S1w, E1w, 0); tr2 = trail("Trail2", E1w, NBw, 0); tr3 = trail("Trail3", NBw, NBw + D3 * L3, 0)

def fader(base, name):
    m = base.copy(); m.name = name; nt = m.node_tree; out = nt.nodes["Material Output"]; sh = out.inputs[0].links[0].from_socket
    tr = nt.nodes.new("ShaderNodeBsdfTransparent"); mx = nt.nodes.new("ShaderNodeMixShader"); v = nt.nodes.new("ShaderNodeValue"); v.outputs[0].default_value = 0
    nt.links.new(v.outputs[0], mx.inputs[0]); nt.links.new(tr.outputs[0], mx.inputs[1]); nt.links.new(sh, mx.inputs[2]); nt.links.new(mx.outputs[0], out.inputs[0]); return m, v
LT_MAT, LT_EM = emissive("LogoTrail", srgb("#FFCF6E"), 0)
# ---------- logo set ----------
def prism(name, pts, z0, z1, mat, bevel=.05):
    me = bpy.data.meshes.new(name); bm = bmesh.new(); f = bm.faces.new([bm.verts.new(P(x, y, z0)) for x, y in pts])
    if f.normal.z < 0: f.normal_flip()
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, vec=Vector((0, 0, z1 - z0)), verts=[e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
    o = link(bpy.data.objects.new(name, me)); o.data.materials.append(mat)
    bv = o.modifiers.new("b", "BEVEL"); bv.width = bevel; bv.segments = 4; bv.limit_method = "ANGLE"; LOGO.append(o); return o
TOP = [(252, 242), (726, 242), (586, 382), (112, 382)]
a0 = math.atan2(802 - 724, 300 - 244); a1 = math.atan2(687.6 - 724, 331.4 - 244)
BOT = [(331.4, 687.6), (357, 662), (892, 662), (752, 802), (300, 802)] + \
      [(244 + NOTCH * math.cos(a0 + (a1 - a0) * i / 32), 724 + NOTCH * math.sin(a0 + (a1 - a0) * i / 32)) for i in range(1, 32)]
top = prism("TopBar", TOP, F, D, GOLD); bot = prism("BotBar", BOT, F, D, GOLD)
lts = [trail("LT1", S1, E1, 1, .035, LOGO), trail("LT2", E1, NB, 1, .035, LOGO), trail("LT3", NB, P(820, 724), 1, .035, LOGO)]
for o in lts: o.data.materials[0] = LT_MAT
bpy.ops.mesh.primitive_uv_sphere_add(segments=96, ring_count=48, radius=R, location=NB)
lball = bpy.context.object; lball.data.materials.append(IVORY); bpy.ops.object.shade_smooth(); LOGO.append(lball)
lcue = link(bpy.data.objects.new("LogoCue", None)); lcue.location = NB; lcue.rotation_euler = (0, 0, math.radians(45)); LOGO.append(lcue)
def cseg(s0, s1, r0, r1, mat):
    bpy.ops.mesh.primitive_cone_add(vertices=64, radius1=r0 * S, radius2=r1 * S, depth=(s1 - s0) * S)
    o = bpy.context.object; o.data.materials.append(mat); bpy.ops.object.shade_smooth()
    o.rotation_euler = (0, math.radians(90), 0); o.location = ((s0 + s1) / 2 * S, 0, 0); o.parent = lcue; LOGO.append(o)
cseg(78, 130, 19, 21, IVORY); cseg(137, 566, 21, 35.5, GOLD); cseg(566, 736, 36, 40, GOLD)
bpy.ops.mesh.primitive_uv_sphere_add(radius=40 * S); cp = bpy.context.object; cp.scale = (.22, 1, 1); cp.location = (736 * S, 0, 0); cp.parent = lcue; cp.data.materials.append(GOLD); LOGO.append(cp)
bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, F)); lf = bpy.context.object; lf.scale = (90, 60, 1); lf.data.materials.append(FELTL); LOGO.append(lf)
if FONT and os.path.exists(FONT):
    tc = bpy.data.curves.new("Word", "FONT"); tc.body = "ZOKERVIE"; tc.font = bpy.data.fonts.load(FONT)
    tc.size = 1.4; tc.space_character = 1.3; tc.align_x = "CENTER"; tc.align_y = "CENTER"; tc.extrude = .03
    wm_mat, wm_v = fader(GOLD, "WordGold"); word = link(bpy.data.objects.new("Word", tc)); word.data.materials.append(wm_mat); LOGO.append(word)
    if SUB:
        IVM = principled("SubIvory", **{"Base Color": srgb("#F7EFDC"), "Roughness": .6}); sb_mat, sb_v = fader(IVM, "SubFade")
        t2 = bpy.data.curves.new("Sub", "FONT"); t2.body = "BILLIARDS"; t2.font = tc.font
        t2.size = .5; t2.space_character = 2.3; t2.align_x = "CENTER"; t2.align_y = "CENTER"; t2.extrude = .01
        sub = link(bpy.data.objects.new("Sub", t2)); sub.data.materials.append(sb_mat); LOGO.append(sub)
    else: sub = None
else: word = None; sub = None

# ---------- lights ----------
def area(name, loc, size, energy, color, target, group, size_y=None, spread=None):
    l = bpy.data.lights.new(name, "AREA"); l.size = size; l.energy = energy; l.color = color
    if size_y: l.shape = "RECTANGLE"; l.size_y = size_y
    if spread: l.spread = spread
    o = link(bpy.data.objects.new(name, l)); o.location = loc; o.visible_camera = False
    o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler(); group.append(o); return o
lamp = area("TableLamp", (-2, -1, F + 24), 10, 15000, (1, .93, .8), (-2, -1, F), TABLE, size_y=34, spread=math.radians(100))
lamp.rotation_euler = (0, 0, A)
back = area("DustBack", S1w + Vector((3.5, 7, 3.2)), 2.0, 420, (.75, .86, 1), S1w + Vector((-R, 0, 0)), TABLE, spread=math.radians(60))
keyl = area("StrikeKey", S1w + Vector((-4, -6, 5)), 4, 160, (1, .9, .75), S1w, TABLE)
area("LLamp", (0, 5, 14), 14, 1500, (1, .93, .8), (0, -1, F), LOGO); area("LRimL", (-12, -4, 3), 5, 1600, (1, .8, .5), (0, 0, F), LOGO)
area("LRimR", (12, 5, 2), 4, 1100, (1, .86, .62), (0, 0, F), LOGO)
bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 2, 48)); card = bpy.context.object; card.scale = (70, 34, 1); card.rotation_euler = (math.pi, 0, 0)
cm, ce = emissive("Card", (1, .86, .62, 1), 1); nt = cm.node_tree
tcn = nt.nodes.new("ShaderNodeTexCoord"); mpn = nt.nodes.new("ShaderNodeMapping"); mpn.inputs["Rotation"].default_value = (0, 0, math.radians(35))
gr = nt.nodes.new("ShaderNodeTexWave"); gr.inputs["Scale"].default_value = 3.2; gr.inputs["Distortion"].default_value = 1.2; gr.inputs["Detail"].default_value = 1; mrn = nt.nodes.new("ShaderNodeMapRange"); mrn.inputs["To Min"].default_value = .04; mrn.inputs["To Max"].default_value = .75
nt.links.new(tcn.outputs["Object"], mpn.inputs["Vector"]); nt.links.new(mpn.outputs["Vector"], gr.inputs["Vector"])
nt.links.new(gr.outputs["Fac"], mrn.inputs["Value"]); nt.links.new(mrn.outputs["Result"], ce.inputs[1])
card.data.materials.append(cm); card.visible_camera = False; card.visible_shadow = False; LOGO.append(card)
swd = bpy.data.lights.new("Sweep", "POINT"); swd.energy = 0; swd.color = (1, .96, .86); sweep = link(bpy.data.objects.new("Sweep", swd)); LOGO.append(sweep)

cam_d = bpy.data.cameras.new("Cam"); cam_d.dof.use_dof = True; cam = link(bpy.data.objects.new("Cam", cam_d)); sc.camera = cam
def aim(c, l, lens, fstop, focus=None):
    c, l = Vector(c), Vector(l); cam.location = c; fw = (l - c).normalized()
    up = Vector((0, 1, 0)) if abs(fw.z) > .95 else Vector((0, 0, 1))
    rt = fw.cross(up).normalized(); up = rt.cross(fw); cam.rotation_euler = Matrix((rt, up, -fw)).transposed().to_euler()
    cam_d.lens = lens; cam_d.dof.aperture_fstop = fstop; cam_d.dof.focus_distance = focus or (l - c).length

sc.use_nodes = True; ct = sc.node_tree; ct.nodes.clear()
rl = ct.nodes.new("CompositorNodeRLayers"); co = ct.nodes.new("CompositorNodeComposite"); gl = ct.nodes.new("CompositorNodeGlare")
try: gl.glare_type = "BLOOM"
except Exception: pass
for k, v in (("Threshold", 1.2), ("Strength", .5), ("Size", .55)):
    if k in gl.inputs: gl.inputs[k].default_value = v
ct.links.new(rl.outputs["Image"], gl.inputs["Image"]); ct.links.new(gl.outputs["Image"], co.inputs["Image"])

sc.render.fps = FPS; sc.frame_start, sc.frame_end = 0, NF - 1
sc.render.use_persistent_data = True; sc.render.use_motion_blur = True; sc.render.motion_blur_shutter = 0.3
def clamp(x): return max(0.0, min(1.0, x))
def seg(t, a, b): return clamp((t - a) / (b - a))
def sine(u): return -(math.cos(math.pi * u) - 1) / 2
def pout(u, k=2): return 1 - (1 - u) ** k
def expo_in(u): return 0.0 if u <= 0 else 2 ** (10 * u - 10)
def back_out(u, s=1.7):
    u -= 1; return u * u * ((s + 1) * u + s) + 1
T_STRIKE, T_CUT1, T_C1, T_C2, T_STOP, T_CUT2 = .9, 1.6, 2.4, 3.2, 3.7, 3.95
def f1(t):
    if t < T_STRIKE: return 0.0
    if t < T_CUT1: return .015 * seg(t, T_STRIKE, T_CUT1)
    return .015 + .985 * seg(t, T_CUT1, T_C1)
def f2(t): return pout(seg(t, T_C1, T_C2), 1.35)
def f3(t): return .55 * pout(seg(t, T_C2, T_STOP), 2.2)
def table_ball(t):
    if t < T_C1: return S1w.lerp(E1w, f1(t))
    if t < T_C2: return E1w.lerp(NBw, f2(t))
    return NBw + D3 * f3(t)
BALL_END = table_ball(T_STOP)
def cue_gap(t):    # tip distance behind the ball surface
    if t < .5: return 2.2 - 1.6 * pout(seg(t, 0, .5), 3)
    if t < .72: return .6 + .7 * sine(seg(t, .5, .72))
    if t < T_STRIKE: return 1.3 - 1.3 * expo_in(seg(t, .72, T_STRIKE))
    return -.3 * pout(seg(t, T_STRIKE, T_CUT1))
SHOT1 = [dust, back, keyl, rcue] + list(rcue.children)
SHOT2 = [tr1, tr2, tr3, sparks, sparks2]
def aim_at(c, l):
    c, l = Vector(c), Vector(l); cam.location = c; fw = (l - c).normalized()
    up = Vector((0, 1, 0)) if abs(fw.z) > .95 else Vector((0, 0, 1))
    rt = fw.cross(up).normalized(); up = rt.cross(fw); cam.rotation_euler = Matrix((rt, up, -fw)).transposed().to_euler()
TOPC, TOPL = Vector((0, -1, F + 72)), Vector((0, -1, F))
LOGY = -1.45 if SUB else -1.0
LOGC, LOGL = Vector((0, LOGY, 27.4)), Vector((0, LOGY, F))
last = {}
def vis(o, f, show_it):
    h = not show_it
    if last.get(o.name) != h: o.hide_render = h; o.keyframe_insert("hide_render", frame=f); last[o.name] = h
for f in range(NF):
    t = f / FPS; shot = 1 if t < T_CUT1 else (2 if t < T_CUT2 else 3)
    for o in TABLE: vis(o, f, shot < 3 and (shot == 1 or o not in SHOT1) and (shot == 2 or o not in SHOT2))
    for o in LOGO: vis(o, f, shot == 3)
    vis(dust, f, shot == 1 and t >= T_STRIKE - .02)
    vis(sparks, f, shot == 2 and T_C1 <= t < T_C1 + .45); vis(sparks2, f, shot == 2 and T_C2 <= t < T_C2 + .45)
    ball.location = table_ball(min(t, T_CUT2)); ball.keyframe_insert("location", frame=f); vis(ball, f, shot < 3)
    rcue.location = S1w + Vector((-R - cue_gap(t), 0, 0)); rcue.keyframe_insert("location", frame=f)
    dust.scale = [.35 + .65 * pout(seg(t, T_STRIKE, T_CUT1), 2.5)] * 3; dust.keyframe_insert("scale", frame=f)
    sparks.scale = [.1 + .9 * pout(seg(t, T_C1, T_C1 + .4), 2)] * 3; sparks.keyframe_insert("scale", frame=f)
    sparks2.scale = [.1 + .9 * pout(seg(t, T_C2, T_C2 + .4), 2)] * 3; sparks2.keyframe_insert("scale", frame=f)
    tr1.data.bevel_factor_end = f1(t) if t >= T_CUT1 else 0; tr1.data.keyframe_insert("bevel_factor_end", frame=f)
    tr2.data.bevel_factor_end = f2(t); tr2.data.keyframe_insert("bevel_factor_end", frame=f)
    tr3.data.bevel_factor_end = pout(seg(t, T_C2, T_CUT2 - .1), 1.6); tr3.data.keyframe_insert("bevel_factor_end", frame=f)
    TR_EM.inputs[1].default_value = 16 * seg(t, T_CUT1, T_CUT1 + .05); TR_EM.inputs[1].keyframe_insert("default_value", frame=f)
    # camera
    if shot == 1:
        u = sine(seg(t, 0, T_STRIKE)); c = S1w + Vector((-4.8, -8.4, 1.0)).lerp(Vector((-3.6, -6.4, .75)), u)
        c += Vector((.25, .4, 0)) * seg(t, T_STRIKE, T_CUT1)
        l = S1w + Vector((-1.4, 0, .15)); aim_at(c, l); cam_d.lens = 62; cam_d.dof.aperture_fstop = .6
        cam_d.dof.focus_distance = (S1w + Vector((-R, 0, 0)) - c).length
    elif shot == 2:
        u = expo_in(seg(t, T_STOP - .15, T_CUT2)); c = TOPC.lerp(BALL_END + Vector((0, 0, 5)), u); l = TOPL.lerp(BALL_END, u)
        aim_at(c, l); cam_d.lens = 46 + 6 * seg(t, T_CUT1, T_STOP); cam_d.dof.aperture_fstop = 11; cam_d.dof.focus_distance = (l - c).length
    else:
        u = pout(seg(t, T_CUT2, 4.75), 3); c = (NB + Vector((0, 0, 5))).lerp(LOGC, u); l = NB.lerp(LOGL, u)
        aim_at(c, l); cam_d.lens = 50; cam_d.dof.aperture_fstop = 8; cam_d.dof.focus_distance = (l - c).length
    cam.keyframe_insert("location", frame=f); cam.keyframe_insert("rotation_euler", frame=f)
    cam_d.keyframe_insert("lens", frame=f); cam_d.dof.keyframe_insert("focus_distance", frame=f); cam_d.dof.keyframe_insert("aperture_fstop", frame=f)
    # flash across the cut
    ex = 3.5 * seg(t, T_STOP, T_CUT2) ** 2 if t < T_CUT2 else 3.5 * (1 - pout(seg(t, T_CUT2, 4.3), 2))
    sc.view_settings.exposure = ex; sc.view_settings.keyframe_insert("exposure", frame=f)
    # logo build: glow lines hand over to gold bars, cue rises, word fades in, light sweeps
    LT_EM.inputs[1].default_value = 16 * (1 - seg(t, 4.1, 4.7)) if shot == 3 else 0; LT_EM.inputs[1].keyframe_insert("default_value", frame=f)
    top.location.z = -1.0 * (1 - back_out(seg(t, 4.0, 4.32), 1.4)); top.keyframe_insert("location", frame=f)
    bot.location.z = -1.0 * (1 - back_out(seg(t, 4.15, 4.47), 1.4)); bot.keyframe_insert("location", frame=f)
    lcue.location = NB + Vector((0, 0, -1.2 * (1 - back_out(seg(t, 4.3, 4.62), 1.6)))); lcue.keyframe_insert("location", frame=f)
    if word:
        w = pout(seg(t, 4.7, 5.3), 3); word.location = (0, -4.75 + .25 * w, F + .02); word.keyframe_insert("location", frame=f)
        wm_v.outputs[0].default_value = w; wm_v.outputs[0].keyframe_insert("default_value", frame=f)
    if sub:
        w2 = pout(seg(t, 4.95, 5.5), 3); sub.location = (0, -5.95 + .15 * w2, F + .02); sub.keyframe_insert("location", frame=f)
        sb_v.outputs[0].default_value = w2; sb_v.outputs[0].keyframe_insert("default_value", frame=f)
    u = seg(t, 4.65, 5.4); sweep.location = (-7 + 14 * u, 1 - 3 * u, 3); sweep.keyframe_insert("location", frame=f)
    swd.energy = math.sin(math.pi * u) * 2200; swd.keyframe_insert("energy", frame=f)

def linearize(idb):
    ad = getattr(idb, "animation_data", None)
    if ad and ad.action:
        for fc in ad.action.fcurves:
            for kp in fc.keyframe_points: kp.interpolation = "CONSTANT" if fc.data_path == "hide_render" else "LINEAR"
for o in list(sc.objects) + [cam_d, sc, swd] + [x.data for x in (tr1, tr2, tr3)]: linearize(o)
for m in (TR_MAT, LT_MAT) + ((wm_mat,) if word else ()) + ((sb_mat,) if sub else ()): linearize(m.node_tree)
if VIDEO:
    sc.render.image_settings.file_format = "FFMPEG"; ff = sc.render.ffmpeg
    ff.format = "MPEG4"; ff.codec = "H264"; ff.constant_rate_factor = "HIGH"; ff.ffmpeg_preset = "GOOD"
    if WAV:
        ff.audio_codec = "AAC"; ff.audio_bitrate = 256; ff.audio_channels = "STEREO"; ff.audio_mixrate = 48000
        se = sc.sequence_editor_create(); coll = getattr(se, "strips", None) or se.sequences; coll.new_sound("sfx", WAV, channel=1, frame_start=0)
    sc.render.filepath = os.path.join(OUT, "zokervie-intro-c.mp4")
else:
    sc.render.filepath = os.path.join(OUT, "f_####")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "zokervie-intro-c.blend"))
if FR:
    a, b2 = (int(x) for x in FR.split("-")); sc.frame_start, sc.frame_end = a, b2
bpy.ops.render.render(animation=True)
print("ZKV_DONE")
