#!/usr/bin/env python3
"""Validate BigWigs bundle structure before uploading artifacts."""
from pathlib import Path
import zipfile

roots = {"ForeverCommsVoice", "ForeverGuildComms", "ForeverGroupComms"}
zips = list(Path('.release').glob('*.zip'))
if not zips:
    raise SystemExit('ERROR: BigWigs did not create a .release/*.zip archive')
for path in zips:
    with zipfile.ZipFile(path) as arc:
        bad = arc.testzip()
        if bad:
            raise SystemExit(f'ERROR: corrupt {path}: {bad}')
        names = set(arc.namelist())
        top = {n.split('/', 1)[0] for n in names if n and not n.endswith('/')}
        if top != roots:
            raise SystemExit(f'ERROR: {path}: expected only {sorted(roots)}; got {sorted(top)}')
        for addon in roots:
            if f'{addon}/{addon}.toc' not in names:
                raise SystemExit(f'ERROR: missing {addon}.toc in {path}')
        for addon in ('ForeverGuildComms', 'ForeverGroupComms'):
            toc = arc.read(f'{addon}/{addon}.toc').decode('utf-8-sig')
            if '## Dependencies: ForeverCommsVoice' not in toc:
                raise SystemExit(f'ERROR: broken Voice dependency in {addon}')
        if any('/tests/' in n or '/install/' in n or '/.github/' in n for n in names):
            raise SystemExit(f'ERROR: nonruntime contents in {path}')
    print(f'PASS: {path} ({len(names)} entries)')
