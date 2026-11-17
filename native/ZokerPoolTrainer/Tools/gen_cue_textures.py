#!/usr/bin/env python3
"""0.44.1 M3: procedural cue textures (no external images). Writes image sets into BankLab/Assets.xcassets:

  CueTex0441-maple     shaft: pale maple, fine straight grain along the cue (v = along, u = around)
  CueTex0441-grain     butt wood grain, neutral grey (the app multiplies it by each cue's colour)
  CueTex0441-carbon    2x2 twill carbon weave, neutral grey
  CueTex0441-wrap      Irish-linen wrap weave, neutral grey (multiplied by the wrap colour)
  CueTex0441-fa-<id>   forearm with inlays for the 10 Zoker designs (points, stone ovals, diamonds, waves, scales)

Texture layout matches the lathe mesh in BankLab/Rendering/CueModel0441.swift: u = angle around the cue (0…1),
v = along the section (0 = joint/tip end, 1 = butt end). Deterministic (fixed seeds): re-running gives identical files.
Usage: python3 Tools/gen_cue_textures.py
"""
import json, math, os, random
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'BankLab', 'Assets.xcassets')

# Mirror of CueLook.designs044 (EquipmentLibrary.swift): id, inlay, body, accent, inlayColor, stone, carbon
DESIGNS = [
    ("zmz01", 1, 0x17120f, 0xd9c79a, 0xE8D6A8, 0xE8D6A8, False),
    ("zmc02", 2, 0x6B4A2E, 0xC9A55A, 0x101010, 0x22B5A8, False),
    ("zjb03", 1, 0x6E3B22, 0xC0C4C8, 0x0B0B0B, 0xC0C4C8, False),
    ("zlu04", 3, 0x0E0F10, 0xC8A04A, 0xC8A04A, 0x1F8A55, False),
    ("zvk05", 3, 0xE9EDF0, 0x2D6FD6, 0x2D6FD6, 0x5FA8FF, False),
    ("zsc06", 1, 0x5A1F14, 0xEDE3C8, 0xF0E7CF, 0x0E0E0E, False),
    ("zmu07", 4, 0x8A1622, 0xD9B24C, 0xD9B24C, 0xF2E6C4, False),
    ("zps08", 2, 0x0A0A0B, 0xBFC6CC, 0xBFC6CC, 0x9FD6D2, True),
    ("zpe09", 1, 0x9A5A22, 0x111111, 0x151210, 0xF0A33A, False),
    ("zld10", 5, 0x0C0C0E, 0xC2272D, 0xC2272D, 0xF26A3A, True),
]

def rgb(h): return ((h >> 16) & 255, (h >> 8) & 255, h & 255)

def save(name, image):
    folder = os.path.join(ROOT, name + '.imageset')
    os.makedirs(folder, exist_ok=True)
    image.save(os.path.join(folder, 'tex.png'), optimize=True)
    with open(os.path.join(folder, 'Contents.json'), 'w') as f:
        json.dump({"images": [{"filename": "tex.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}, f, indent=2)

def grain(w, h, seed, base, depth, lines=70, wobble=6.0):
    """Long-grain wood: bands along v, slightly wavy around u, plus fine pores. base/depth in 0…255 grey."""
    rnd = random.Random(seed)
    img = Image.new('L', (w, h), base)
    d = ImageDraw.Draw(img)
    for _ in range(lines):
        u0 = rnd.uniform(0, w); width = rnd.uniform(0.6, 3.2); tone = base - rnd.uniform(0.25, 1.0) * depth
        phase = rnd.uniform(0, 6.28); freq = rnd.uniform(1.5, 4.0)
        pts = [(u0 + wobble * math.sin(phase + freq * v / h * 6.28), v) for v in range(0, h + 8, 8)]
        for x_off in (-w, 0, w):   # wrap around u
            d.line([(x + x_off, y) for x, y in pts], fill=int(max(0, tone)), width=max(1, int(width)))
    for _ in range(w * h // 90):   # pores
        x, y = rnd.randrange(w), rnd.randrange(h)
        d.line([(x, y), (x, y + rnd.randint(2, 7))], fill=int(base - depth * 0.6))
    return img.filter(ImageFilter.GaussianBlur(0.6))

def tint(gray, colour, strength=1.0):
    r, g, b = rgb(colour)
    out = Image.merge('RGB', [gray.point(lambda v, c=c: int(c * (1 - strength + strength * v / 255))) for c in (r, g, b)])
    return out

def carbon(w=256, h=256):
    img = Image.new('L', (w, h), 40); d = ImageDraw.Draw(img); s = 16
    for i in range(0, w, s):
        for j in range(0, h, s):
            k = ((i // s) + (j // s)) % 4
            tone = 70 if k < 2 else 30
            if k % 2 == 0: d.rectangle([i, j, i + s - 1, j + s // 2 - 1], fill=tone + 30); d.rectangle([i, j + s // 2, i + s - 1, j + s - 1], fill=tone)
            else: d.rectangle([i, j, i + s // 2 - 1, j + s - 1], fill=tone + 30); d.rectangle([i + s // 2, j, i + s - 1, j + s - 1], fill=tone)
    return img.filter(ImageFilter.GaussianBlur(0.8))

def linen(w=256, h=256):
    rnd = random.Random(7); img = Image.new('L', (w, h), 120); d = ImageDraw.Draw(img)
    for v in range(0, h, 4):   # wound thread, slight diagonal
        tone = 150 + rnd.randint(-25, 25)
        d.line([(0, v), (w, v + 3)], fill=tone, width=2)
    for u in range(0, w, 6):
        d.line([(u, 0), (u, h)], fill=95 + rnd.randint(-10, 10), width=1)
    return img.filter(ImageFilter.GaussianBlur(0.5))

def forearm(design, w=256, h=1024):
    cid, inlay, body, accent, inlay_c, stone, is_carbon = design
    base = tint(carbon(w, w).resize((w, w)), body, 0.9) if is_carbon else tint(grain(w, h, sum(map(ord, cid)), 225, 70), body, 0.85)
    if is_carbon:
        full = Image.new('RGB', (w, h)); [full.paste(base, (0, y)) for y in range(0, h, w)]; base = full
    d = ImageDraw.Draw(base)
    A, I, S = rgb(accent), rgb(inlay_c), rgb(stone)
    if inlay == 1:   # classic points from the wrap end (v = 1) toward the joint, with veneers and a stone eye
        for k in range(4):
            x = k * 64 + 32
            for wd, col in ((26, A), (20, I)):
                d.polygon([(x - wd, h), (x, 180), (x + wd, h)], fill=col)
            d.ellipse([x - 7, 560, x + 7, 600], fill=S)
    elif inlay == 2:   # stone ovals in staggered rings with metal windows
        for row in range(3):
            for k in range(4):
                x = k * 64 + 32 + (0 if row % 2 == 0 else 32); y = 250 + row * 200
                d.ellipse([x - 17, y - 44, x + 17, y + 44], fill=I); d.ellipse([x - 12, y - 38, x + 12, y + 38], fill=S)
    elif inlay == 3:   # diamonds with stone centres
        for row in range(4):
            for k in range(4):
                x = k * 64 + 32; y = 180 + row * 210
                d.polygon([(x, y - 60), (x + 22, y), (x, y + 60), (x - 22, y)], fill=I); d.ellipse([x - 8, y - 16, x + 8, y + 16], fill=S)
    elif inlay == 4:   # gold waves
        for row in range(6):
            y0 = 140 + row * 150
            pts = [(x, y0 + 18 * math.sin(x / 256 * 2 * math.pi * 2)) for x in range(0, 257, 4)]
            d.line(pts, fill=I, width=7)
    elif inlay == 5:   # dragon scales
        for row in range(16):
            for k in range(9):
                x = k * 32 + (0 if row % 2 == 0 else 16); y = 80 + row * 58
                d.arc([x - 16, y - 16, x + 16, y + 16], 0, 180, fill=(S if row % 3 == 0 else I), width=3)
    d.rectangle([0, 0, w, 10], fill=A); d.rectangle([0, h - 10, w, h], fill=A)
    return base

if __name__ == '__main__':
    save('CueTex0441-maple', tint(grain(128, 1024, 11, 238, 38, lines=55, wobble=2.0), 0xEAD7B0, 1.0))
    save('CueTex0441-grain', grain(256, 1024, 23, 235, 80).convert('RGB'))
    save('CueTex0441-carbon', carbon().convert('RGB'))
    save('CueTex0441-wrap', linen().convert('RGB'))
    for design in DESIGNS:
        save('CueTex0441-fa-' + design[0], forearm(design))
    print('PASS cue textures:', 4 + len(DESIGNS), 'image sets in BankLab/Assets.xcassets (procedural, no external images)')
