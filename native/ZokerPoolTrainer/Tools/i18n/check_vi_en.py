#!/usr/bin/env python3
"""0.45 M3: every user-visible Vietnamese string must have an English entry (L10n.table in BankLab/UI/L10n042.swift or
the I18N_en catalog). Scans string literals in BankLab/**/*.swift that contain Vietnamese letters and are passed to a
UI text entry point (text/title/caption/message/notifyStatus/say/lab/toggle/segmented/header/UIAlertAction/…).
A literal counts as covered if it is a catalog key, or if every Vietnamese phrase in it is (L10n translates known
phrases inside dynamic text). Usage: python3 Tools/i18n/check_vi_en.py [--since <git-ref>]  (exit 1 on any gap)."""
import json, os, re, subprocess, sys
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
VI = re.compile(r'[ạảãàáâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđĐ]', re.I)
UI = re.compile(r'(text\s*=|title\s*[:=]|caption\s*:|message\s*:|notifyStatus\(|say\(|\.lab\(|toggle\(|segmented\(|header\(|showCoach\(|setTitle\(|accessibilityLabel\s*=|subtitle\s*[:=]|configuration\?\.title\s*=|\bc\.title\s*=)')
LIT = re.compile(r'"((?:[^"\\]|\\.)*)"')

def catalog():
    keys = set()
    src = ''.join(open(os.path.join(ROOT, f), encoding='utf-8').read() for f in ('BankLab/UI/L10n042.swift', 'BankLab/UI/L10nTable059.swift'))   # 0.59: table moved
    for m in re.finditer(r'^\s*"((?:[^"\\]|\\.)*)"\s*:\s*\["', src, re.M): keys.add(m.group(1))
    d = os.path.join(ROOT, 'BankLab/Assets.xcassets/I18N_en.dataset/i18n.json')
    keys |= set(json.load(open(d, encoding='utf-8')).keys())
    return keys

def lines(since):
    if since:
        out = subprocess.run(['git', 'diff', '-U0', since, '--', 'BankLab'], cwd=ROOT, capture_output=True, text=True).stdout
        file = None
        for l in out.splitlines():
            if l.startswith('+++ b/'): file = l[6:]
            elif l.startswith('+') and not l.startswith('+++') and file and file.endswith('.swift'): yield file, l[1:]
    else:
        for base, _, files in os.walk(os.path.join(ROOT, 'BankLab')):
            for f in files:
                if f.endswith('.swift'):
                    p = os.path.join(base, f)
                    for l in open(p, encoding='utf-8'): yield os.path.relpath(p, ROOT), l

def main():
    since = sys.argv[sys.argv.index('--since') + 1] if '--since' in sys.argv else None
    keys = catalog(); gaps = []; total = 0
    for f, l in lines(since):
        code = l.split('//')[0] if '"' not in l.split('//')[0][-1:] else l
        if not UI.search(code): continue
        for m in LIT.finditer(code):
            s = m.group(1)
            if not VI.search(s) or '\\(' in s and not VI.search(re.sub(r'\\\(.*?\)', '', s)): continue
            total += 1
            if s in keys: continue
            parts = [p.strip(' ·:%.,!?\n') for p in re.split(r'\\\(.*?\)|%[-+0-9.]*l*[a-z@]|\\n|·', s)]
            parts = [p for p in parts if VI.search(p)]
            if parts and all(p in keys for p in parts): continue
            gaps.append((f, s))
    for f, s in gaps[:200]: print(f'THIẾU en  {f}: "{s}"')
    scope = f'chuỗi mới từ {since}' if since else 'toàn bộ BankLab'
    print(f"{'PASS' if not gaps else 'FAIL'} i18n vi+en ({scope}): {total} chuỗi tiếng Việt hiển thị, thiếu tiếng Anh {len(gaps)}; danh mục {len(keys)} mục")
    sys.exit(0 if not gaps else 1)
main()
