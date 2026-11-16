#!/usr/bin/env python3
"""Run bounded Godot checks; a script-error log is a failure even with exit code 0."""
import argparse
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--godot', required=True)
args = parser.parse_args()
version = subprocess.check_output([args.godot, '--version'], text=True).strip()
if not version.startswith((root/'.godot-version').read_text().strip()):
    raise SystemExit(f'Expected Godot 4.4.1.stable, got {version}')
(root / 'builds').mkdir(exist_ok=True)
log_path = root / 'builds/validation.log'
base = [args.godot, '--headless', '--xr-mode', 'off', '--path', str(root)]
jobs = [('import', ['--editor', '--import', '--quit'])]
jobs += [(str(p.relative_to(root)), ['--script', 'res://' + str(p.relative_to(root))])
         for folder in ['unit', 'integration'] for p in sorted((root/'tests'/folder).glob('test_*.gd'))]
jobs += [('scene-smoke', ['--quit-after', '120'])]
suite = ET.Element('testsuite', name='Spatial Snake', tests=str(len(jobs)))
failed = False
with log_path.open('w') as log:
    for name, flags in jobs:
        started = time.monotonic()
        code = -1
        try:
            result = subprocess.run(base + flags, cwd=root, capture_output=True, text=True, timeout=60)
            output, code = result.stdout + result.stderr, result.returncode
        except subprocess.TimeoutExpired as error:
            output = (error.stdout or b'').decode(errors='replace') if isinstance(error.stdout, bytes) else (error.stdout or '')
            output += '\nERROR: test exceeded 60 seconds\n'
        plain = re.sub(r'\x1b\[[0-9;]*m', '', output)
        log.write(f'\n=== {name} ===\n{plain}')
        log.flush()
        case = ET.SubElement(suite, 'testcase', name=name, time=f'{time.monotonic()-started:.3f}')
        bad = code != 0 or bool(re.search(r'SCRIPT ERROR:|ERROR:|Parse Error:', plain))
        print(('FAIL' if bad else 'PASS') + ' ' + name, flush=True)
        if bad:
            ET.SubElement(case, 'failure', message='Godot check failed').text = plain[-16000:]
            print(plain[-8000:], flush=True)
            failed = True
            break
        for line in plain.splitlines():
            if 'checks,' in line or 'TESTS:' in line: print(line, flush=True)
suite.set('failures', '1' if failed else '0')
ET.ElementTree(suite).write(root/'builds/test-results.xml', encoding='utf-8', xml_declaration=True)
raise SystemExit(1 if failed else 0)
