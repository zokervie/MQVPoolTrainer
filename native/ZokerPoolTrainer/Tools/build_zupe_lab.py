"""Build a dependency-free offline WKWebView bundle; keep each JS module scoped."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
enhancements = root / 'Research/ZUPE/enhancements'
modules = [('bank', 'bank-physics'), ('stroke', 'stroke-control'),
           ('elevated', 'elevated-cue-3d'), ('golden', 'golden-calibration'),
           ('equipment', 'cue-equipment-library'), ('recorder', 'simulation-recorder')]
names = {filename: name for name, filename in modules}
chunks = ['globalThis.Zupe = (() => {\n"use strict";']
for name, filename in modules:
    source = (enhancements / (filename + '.mjs')).read_text()
    exports = re.findall(r'export\s+(?:const|function)\s+(\w+)', source)
    def imported(match):
        return 'const {' + match[1] + '} = ' + names[match[2]] + ';'
    source = re.sub(r"import\s*\{([^}]+)\}\s*from\s*'\./([^']+)\.mjs';", imported, source)
    source = re.sub(r'\bexport\s+(?=const|function)', '', source)
    chunks.append(f'const {name} = (() => {{\n{source}\nreturn Object.freeze({{{",".join(exports)}}});\n}})();')
chunks.append('return Object.freeze({' + ','.join(name for name, _ in modules) + '});\n})();')
bundle = '\n'.join(chunks)
output = root / 'BankLab/ZupeLab'
output.mkdir(exist_ok=True)
template = (root / 'Research/ZUPE/lab-template.html').read_text()
assert template.count('/* ZUPE_BUNDLE */') == 1
(output / 'index.html').write_text(template.replace('/* ZUPE_BUNDLE */', bundle.replace('</script', '<\\/script')))
(output / 'zupe-bundle.js').write_text(bundle)
print('Built offline ZUPE Lab: 6 scoped modules; no CDN or network dependencies')
