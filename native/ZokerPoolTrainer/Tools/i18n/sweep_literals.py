#!/usr/bin/env python3
"""0.59 (owner, video bản 202): collect every Vietnamese string literal the app may show, as the text L10n.tr receives at
run time — interpolations "\\(x)" and format specifiers become "7" (a number or a name both go through templates) —
for Tests/L10nSweepTests.swift. Output: JSON list of {"file","line","text"} on stdout.
Skipped: comments, logs/asserts, defaults keys, QA-only files, the catalog itself."""
import json, os, re, sys
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
VI = re.compile(r'[ạảãàáâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđĐ]', re.I)
SKIP_LINE = re.compile(r'\b(print|debugPrint|NSLog|os_log|assert|assertionFailure|precondition|fatalError)\s*\(|forKey:|UserDefaults|QA\.has|accessibilityIdentifier|Notification\.Name|tags\.append|\.appendingPathComponent|URL\(|"--')
SKIP_FILE = re.compile(r'(QA|L10n042|L10nTable059|L10nCore059|Teaser048)')
LIT = re.compile(r'(?<!")"((?:[^"\\]|\\.)*)"(?!")')

def strip_comment(l):
    q = False; i = 0
    while i < len(l) - 1:
        c = l[i]
        if c == '\\' and q: i += 2; continue
        if c == '"': q = not q
        elif not q and l[i:i + 2] == '//': return l[:i]
        i += 1
    return l

def interp(s, slot='7', fmt_num='7', fmt_obj='7'):
    out = ''; i = 0
    while i < len(s):
        if s.startswith('\\(', i):
            depth = 0; j = i + 1
            while j < len(s):
                if s[j] == '(': depth += 1
                elif s[j] == ')':
                    depth -= 1
                    if depth == 0: break
                j += 1
            out += slot; i = j + 1
        else: out += s[i]; i += 1
    out = re.sub(r'%[-+0-9.]*l*[dfgu]', fmt_num, out)
    out = re.sub(r'%[-+0-9.]*l*[s@]', fmt_obj, out)
    out = out.replace('%%', '%')
    return out.replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\').replace('\\u{2011}', '‑')

items = []; seen = set()
for base, _, files in os.walk(os.path.join(ROOT, 'BankLab')):
    for f in sorted(files):
        if not f.endswith('.swift') or SKIP_FILE.search(f): continue
        p = os.path.join(base, f); rel = os.path.relpath(p, ROOT); in_block = False
        for n, raw in enumerate(open(p, encoding='utf-8'), 1):
            if '"""' in raw: in_block = not in_block; continue
            if in_block: continue
            code = strip_comment(raw)
            if not VI.search(code) or SKIP_LINE.search(code): continue
            for m in LIT.finditer(code):
                s = m.group(1)
                if not VI.search(re.sub(r'\\\(.*?\)', '', s)): continue
                t = interp(s)
                if t in seen: continue
                seen.add(t); items.append({'file': rel, 'line': n, 'text': t, 'key': interp(s, '{}', '#', '{}')})
json.dump(items, sys.stdout, ensure_ascii=False, indent=0)
