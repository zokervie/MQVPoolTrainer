#!/usr/bin/env python3
"""Fail when a Tests/*Tests.cpp file is not run by both Run-All-Checks.command and CMakeLists.txt."""
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
on_disk = {p.name[:-len('Tests.cpp')] for p in (root / 'Tests').glob('*Tests.cpp')}

run_all = (root / 'Run-All-Checks.command').read_text()
match = re.search(r'for suite in ([A-Za-z0-9 ]+); do\n\s+"\$\{compiler', run_all)
if not match:
    sys.exit('check_suite_lists: cannot find the C++ suite loop in Run-All-Checks.command')
in_run_all = set(match.group(1).split())

cmake = (root / 'CMakeLists.txt').read_text()
match = re.search(r'set\(ZOKER_TEST_SUITES([^)]*)\)', cmake)
if not match:
    sys.exit('check_suite_lists: cannot find ZOKER_TEST_SUITES in CMakeLists.txt')
in_cmake = set(match.group(1).split())

problems = []
for name, listed in (('Run-All-Checks.command', in_run_all), ('CMakeLists.txt', in_cmake)):
    if missing := sorted(on_disk - listed):
        problems.append(f'{name} does not run: {", ".join(missing)}')
    if extra := sorted(listed - on_disk):
        problems.append(f'{name} lists suites with no test file: {", ".join(extra)}')
if problems:
    sys.exit('check_suite_lists FAILED\n' + '\n'.join(problems))
print(f'PASS suite lists: {len(on_disk)} C++ suites run by Run-All-Checks and CMake')
