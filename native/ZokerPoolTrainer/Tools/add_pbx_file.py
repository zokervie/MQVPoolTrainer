"""Register a new source/resource file in ZokerPoolTrainer.xcodeproj (no Xcode on Linux).
Usage: python3 Tools/add_pbx_file.py UI/NewFile.swift [more paths relative to BankLab/]
Swift/ObjC++ files go to the app Sources phase; anything else to Resources. Idempotent."""
import re,sys,hashlib
from pathlib import Path
P=Path(__file__).resolve().parents[1]/'ZokerPoolTrainer.xcodeproj/project.pbxproj'
s=P.read_text()
TYPES={'.swift':'sourcecode.swift','.mm':'sourcecode.cpp.objcpp','.hpp':'sourcecode.cpp.h','.h':'sourcecode.c.h','.json':'text.json','.jpg':'image.jpeg','.png':'image.png','.xcstrings':'text.json.xcstrings','.strings':'text.plist.strings'}
GROUP='3A2A88DEEFF3D1D23E496597'
def ids(path):
    h=hashlib.sha1(path.encode()).hexdigest().upper()[:21]
    return 'A042'+h[:20],'C042'+h[:20]
def phase_with(ref):
    m=re.search(r'(\w{24}) = \{ isa = PBX(Sources|Resources)BuildPhase;[^\n]*?\b'+ref+r'\b',s)
    return m
for path in sys.argv[1:]:
    if f'path = "{path}"' in s: print('already',path);continue
    ext=Path(path).suffix;fid,bid=ids(path)
    ftype=TYPES.get(ext,'file')
    line=f'{fid} = {{ isa = PBXFileReference; lastKnownFileType = {ftype}; path = "{path}"; sourceTree = "<group>"; }};\n{bid} = {{ isa = PBXBuildFile; fileRef = {fid}; }};\n'
    s=s.replace('C01800000000000000000001 = { isa = PBXBuildFile; fileRef = A01800000000000000000001; };\n','C01800000000000000000001 = { isa = PBXBuildFile; fileRef = A01800000000000000000001; };\n'+line,1)
    s=re.sub(r'('+GROUP+r' = \{ isa = PBXGroup; children = \()',r'\g<1>'+fid+',',s,count=1)
    anchor='C01800000000000000000007' if ext in ('.swift','.mm') else None
    if anchor:
        s=re.sub(r'(isa = PBXSourcesBuildPhase;[^\n]*?files = \()([^\n]*?\b'+anchor+r'\b)',lambda m:m.group(1)+bid+','+m.group(2),s,count=1)
    else:
        s=re.sub(r'(isa = PBXResourcesBuildPhase;[^\n]*?files = \()([^\n]*?3685E330EC5277A9DD5661C6|[^\n]*?)',lambda m:m.group(1)+bid+','+m.group(2),s,count=1)
    assert bid+',' in s,('phase not found',path)
    print('added',path,fid)
P.write_text(s)
