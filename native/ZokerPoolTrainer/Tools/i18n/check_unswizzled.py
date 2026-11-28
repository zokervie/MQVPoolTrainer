#!/usr/bin/env python3
"""0.59 ZB-045: Vietnamese literals passed to APIs that the L10n swizzle (L10n042.swift) never sees stay Vietnamese in English.
UIBarButtonItem(title:) is not swizzled; TouchControls draws its labels straight into an image. Such literals must be wrapped
in L10n.tr(...). Exit 1 and list them otherwise."""
import re, sys, pathlib
VI = re.compile("[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđĐÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸ]")
RULES = [(re.compile(r'UIBarButtonItem\(title: ?"([^"]*)"'), "UIBarButtonItem(title:) is not swizzled"),
         (re.compile(r'\(\("([^"]*)",[-0-9.]+,[-0-9.]+\)'), "label drawn into an image")]
root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "BankLab")
# Vietnamese without diacritics ("Xong") is caught by being a key of the English catalog.
import json
KEYS = set(json.load(open(root / "Assets.xcassets/I18N_en.dataset/i18n.json", encoding="utf-8")))
KEYS |= set(re.findall(r'^\s*"([^"]+)": \[', (root / "UI/L10nTable059.swift").read_text(encoding="utf-8"), re.M))
bad = []
for f in sorted(root.rglob("*.swift")):
    for n, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
        for rx, why in RULES:
            for m in rx.finditer(line):
                if VI.search(m.group(1)) or m.group(1) in KEYS: bad.append(f"{f}:{n}: {why}: \"{m.group(1)}\" (wrap in L10n.tr)")
for b in bad: print("LEAK " + b)
print(f"REPORT unswizzled literals: {len(bad)}")
print("PASS check_unswizzled" if not bad else "FAIL check_unswizzled")
sys.exit(1 if bad else 0)
