# Zokervie intro C "Cú đánh hai băng" - 3 key stills for approval. Blender 4.5 LTS, built by script.
# Blender -b -P zokervie_intro_c_stills.py -- --out DIR [--w 1280 --h 720] [--samples 64] [--shots 1,2,3] [--font TTF]
# Geometry note: the Z is an exact mirror-reflection two-cushion path between the two long rails;
# the table is turned 22.5 deg in frame so legs 1 and 3 are horizontal and leg 2 runs at 45 deg.
import bpy, bmesh, math, random, sys, os
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(n, d=None): return argv[argv.index(n) + 1] if n in argv else d
OUT = arg("--out", "/tmp/zkvc"); FONT = arg("--font")
W, H, SAMPLES = int(arg("--w", "1280")), int(arg("--h", "720")), int(arg("--samples", "64"))
SHOTS = [int(x) for x in arg("--shots", "1,2,3").split(",")]
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
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=size * random.uniform(.35, 1.0), matrix=Matrix.Translation(p))
    bm.to_mesh(me); bm.free(); o = link(bpy.data.objects.new(name, me)); o.data.materials.append(mat); TABLE.append(o); return o
DUST = principled("ChalkDust", **{"Base Color": srgb("#7FAEE6"), "Roughness": 1, "Emission Color": srgb("#7FAEE6"), "Emission Strength": .08})
dust = specks("dust", S1w + Vector((-R - .05, 0, 0)), 1700, DUST, .0075, 1.35, Vector((-.9, 0, .7)))
SPK, _ = emissive("Spark", srgb("#FFD98A"), 40)
sparks = specks("sparks", E1w + Vn * (R * .8) + Vector((0, 0, -.2)), 90, SPK, .07, 2.6, -Vn * 1.4 + Vector((0, 0, .5)))

TR_MAT, TR_EM = emissive("Trail", srgb("#FFCF6E"), 16)
def trail(name, a, b, frac=1.0, depth=.15, group=TABLE):
    cu = bpy.data.curves.new(name, "CURVE"); cu.dimensions = "3D"; sp = cu.splines.new("POLY"); sp.points.add(1)
    for i, p in enumerate((a, b)): sp.points[i].co = (p.x, p.y, F + .01, 1)
    cu.bevel_depth = depth; cu.bevel_resolution = 3; cu.bevel_factor_mapping_end = "SPLINE"; cu.bevel_factor_end = frac
    o = link(bpy.data.objects.new(name, cu)); o.data.materials.append(TR_MAT); group.append(o); return o
LEG2 = .62
tr1 = trail("Trail1", S1w, E1w); tr2 = trail("Trail2", E1w, NBw, LEG2)

# ---------- logo set (still 3) ----------
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
prism("TopBar", TOP, F, D, GOLD); prism("BotBar", BOT, F, D, GOLD)
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
    word = link(bpy.data.objects.new("Word", tc)); word.data.materials.append(GOLD); word.location = (0, -4.5, F + .02); LOGO.append(word)

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

def show(table, logo):
    for o in TABLE: o.hide_render = not table
    for o in LOGO: o.hide_render = not logo
def shot(n):
    if n == 1:      # slow-motion strike, chalk dust in the back light
        show(True, False); ball.location = S1w; tr1.hide_render = tr2.hide_render = sparks.hide_render = True
        c = S1w + Vector((-3.6, -6.4, .75)); l = S1w + Vector((-1.4, 0, .15)); aim(c, l, 62, .6, (S1w + Vector((-R, 0, 0)) - c).length)
    elif n == 2:    # top view: the Z is a two-cushion shot
        show(True, False); ball.location = E1w.lerp(NBw, LEG2); dust.hide_render = True; back.hide_render = keyl.hide_render = True
        for o in [rcue] + list(rcue.children): o.hide_render = True
        aim((0, -1, F + 72), (0, -1, F), 50, 11)
    else:           # logo resolve
        show(False, True); ball.location = NB; aim((0, -1.0, 27.4), (0, -1.0, F), 50, 8)
    ball.hide_render = False
    sc.render.filepath = os.path.join(OUT, "canh%d.png" % n); bpy.ops.render.render(write_still=True); print("ZKV_SHOT", n)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "zokervie-intro-c.blend"))
for n in SHOTS: shot(n)
print("ZKV_DONE")
