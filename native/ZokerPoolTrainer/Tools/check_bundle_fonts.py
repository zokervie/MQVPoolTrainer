#!/usr/bin/env python3
"""0.58c: the Petemoss font and its OFL licence must be in the app's Copy Bundle Resources, and Info.plist must list the font.
Static check on the project file (no build needed) — run by Run-All-Checks and by Tools/accept_local.sh.
Usage: python3 Tools/check_bundle_fonts.py [path/to/.app]   (with an .app it also checks the built bundle)"""
import plistlib, re, sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
pbx = (root / 'ZokerPoolTrainer.xcodeproj/project.pbxproj').read_text()
need = ['Fonts/Petemoss-Regular.ttf', 'Fonts/OFL.txt']
problems = []

target = re.search(r'\w+ = \{\s*isa = PBXNativeTarget;[^\n]*?buildPhases = \(([^)]*)\);[^\n]*?name = ZokerPoolTrainer;', pbx)
if not target:
    problems.append('app target not found in project.pbxproj')
else:
    phases = [x for x in re.findall(r'\w{24}', target.group(1))]
    res_files = None
    for ph in phases:
        m = re.search(ph + r' = \{\s*isa = PBXResourcesBuildPhase;[^\n]*?files = \(([^)]*)\)', pbx)
        if m:
            res_files = re.findall(r'\w{24}', m.group(1))
    if res_files is None:
        problems.append('app target has no PBXResourcesBuildPhase')
    else:
        for path in need:
            ref = re.search(r'(\w{24}) = \{ isa = PBXFileReference;[^\n]*?path = "' + re.escape(path) + '"', pbx)
            bid = re.search(r'(\w{24}) = \{ isa = PBXBuildFile; fileRef = ' + (ref.group(1) if ref else 'X') + ';', pbx)
            if not ref or not bid or bid.group(1) not in res_files:
                problems.append(path + ' is not in the app target Copy Bundle Resources')

info = plistlib.loads((root / 'BankLab/Info.plist').read_bytes())
if 'Petemoss-Regular.ttf' not in info.get('UIAppFonts', []):
    problems.append('Info.plist UIAppFonts does not list Petemoss-Regular.ttf')

if len(sys.argv) > 1:
    app = Path(sys.argv[1])
    for name in ('Petemoss-Regular.ttf', 'OFL.txt'):
        if not (app / name).exists():
            problems.append(name + ' missing from ' + str(app))

if problems:
    print('FAIL bundle fonts:\n  ' + '\n  '.join(problems)); sys.exit(1)
print('PASS bundle fonts: Petemoss-Regular.ttf + OFL.txt in app Copy Bundle Resources, UIAppFonts set')
