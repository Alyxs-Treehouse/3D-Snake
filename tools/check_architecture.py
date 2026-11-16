#!/usr/bin/env python3
"""Small enforceable dependency rules, complementary to gdformat/gdlint and runtime tests."""
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
errors = []
for file in (root/'src').rglob('*.gd'):
    text = file.read_text()
    relative = file.relative_to(root).as_posix()
    forbidden = []
    if relative.startswith('src/core/') or relative == 'src/gameplay/game_session.gd':
        forbidden = ['XRServer', 'Node3D', 'MeshInstance', 'FileAccess', 'DisplayServer', 'Input.']
    elif relative.startswith('src/platform/'):
        forbidden = ['SnakeModel', 'GameSession', 'ProfileStore']
    elif relative.startswith('src/input/'):
        forbidden = ['GameSession', 'SnakeModel', 'ProfileStore']
    for token in forbidden:
        if token in text:
            errors.append(f'{relative}: forbidden dependency {token}')
    if 'res://scripts/' in text:
        errors.append(f'{relative}: legacy script import')
for folder in ['src','scenes','content']:
    for file in (root/folder).rglob('*'):
        if file.suffix not in {'.gd','.tscn','.tres'}:
            continue
        for path in re.findall(r'"res://([^"\n]+)"', file.read_text()):
            # Generated output paths and parameterized device tracker strings are not resources.
            if path == 'builds' or path.startswith('builds/'):
                continue
            if not (root/path).exists():
                errors.append(f'{file.relative_to(root)}: missing resource {path}')
for error in errors:
    print(error)
print(f'Architecture checks: {len(errors)} errors')
raise SystemExit(bool(errors))
