from pathlib import Path
import re, plistlib, xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
project=(root/'ZokerPoolTrainer.xcodeproj/project.pbxproj').read_text()
ids=['A01100000000000000000001','A01100000000000000000002','A01100000000000000000003','A01100000000000000000004','A01000000000000000000001','A01000000000000000000002','A01000000000000000000003','A01000000000000000000004']
for ref in ids:
 assert len(ref)==24 and len(re.findall(r'^'+ref+r' = ',project,re.M))==1
 assert project.count(ref)>=2
assert 'A01000000000000000000002,' in project and 'A01000000000000000000004,' in project
for file in ['BankLab/UI/ZupeLabController.swift','BankLab/ZupeLab/index.html']:
 assert (root/file).is_file()
controller=(root/'BankLab/UI/TrainingController.swift').read_text()
assert 'ZupeLabController()' in controller and 'ZUPE Lab · nghiên cứu' in controller
native=(root/'BankLab/UI/ZupeLabController.swift').read_text()
assert 'subdirectory: "ZupeLab"' in native and 'zupeExport' in native
html=(root/'BankLab/ZupeLab/index.html').read_text()
assert '/* ZUPE_BUNDLE */' not in html and 'globalThis.Zupe' in html
assert not re.search(r'<script[^>]+src=',html)
assert "connect-src 'none'" in html
for p in (root/'BankLab').glob('*.plist'):
 plistlib.loads(p.read_bytes())
for p in (root/'ZokerPoolTrainer.xcodeproj').rglob('*.xcscheme'):ET.parse(p)
print('PASS: native controller, resource build phase, offline bundle, export bridge, plist and scheme XML; NOT an Xcode compilation')
