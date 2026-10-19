#!/usr/bin/env python3
"""Verify suite packaging without a WoW client, GitHub or external libraries."""
from pathlib import Path
import re
import sys
import zipfile

ROOT = Path(__file__).resolve().parent.parent
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'dist'
ADDONS = ('ForeverCommsVoice', 'ForeverGuildComms', 'ForeverGroupComms')
versions = {}
for addon in ADDONS:
    toc = (ROOT / addon / (addon + '.toc')).read_text()
    versions[addon] = re.search(r'^## Version:\s*(\S+)', toc, re.M).group(1)
    assert '## IconTexture: Interface\\AddOns\\' + addon + '\\Media\\Icon' in toc
    assert (ROOT / addon / 'Media/Icon.tga').exists()
    assert (ROOT / addon / 'Media/ProjectIcon.png').exists()
    assert versions[addon] in (ROOT / addon / 'README.md').read_text()

bundle = f'ForeverComms-Bundle-{versions["ForeverGuildComms"]}.zip'
files = {addon:f'{addon}-{versions[addon]}.zip' for addon in ADDONS}
files['suite'] = bundle
for scope, name in files.items():
    zip_path = OUT / name
    assert zip_path.is_file(), f'Missing {zip_path}'
    with zipfile.ZipFile(zip_path) as z:
        names = set(z.namelist())
        assert z.testzip() is None, f'Corrupt archive: {zip_path}'
        assert 'install/Install-ForeverComms.ps1' in names, 'Missing local installer'
        for addon in ADDONS if scope == 'suite' else ([scope] if scope == 'ForeverCommsVoice' else ['ForeverCommsVoice', scope]):
            assert f'{addon}/{addon}.toc' in names, f'Missing TOC for {addon}'
            assert f'{addon}/Media/Icon.tga' in names, f'Missing runtime icon for {addon}'
            assert f'{addon}/Media/ProjectIcon.png' in names, f'Missing promotional icon for {addon}'
            assert f'{addon}/install/Install-{addon}.ps1' in names
        if scope == 'suite':
            assert '.github/workflows/package.yml' in names, 'Suite workflow not at repository root'
            assert 'tools/package.py' in names
            assert 'package.ps1' in names and 'package.cmd' in names
            assert 'PACKAGING.md' in names
        else:
            assert f'{scope}/install/Install-{scope}.cmd' in names
        for member in names:
            assert not (member.startswith('/') or '..' in Path(member).parts)
    print(f'PASS: {name} ({len(names)} members)')

# Verify restoration scope, and confirm executable local builder vs nested workflows.
settings = (ROOT / 'ForeverGuildComms/Options.lua').read_text()
default_handler = settings.split('function panel.OnDefault()', 1)[1].split('\n    end', 1)[0]
assert 'A.char.voice[key] =' not in default_handler and 'for key, value in pairs(A.voiceDefaults)' not in default_handler
assert 'panel.OnRefresh()' in default_handler
assert 'voice.accentStrength == "expressive"' in (ROOT / 'ForeverCommsVoice/Core.lua').read_text()
assert 'template:sub(-1) == "."' in (ROOT / 'ForeverCommsVoice/Core.lua').read_text()
assert 'ForeverCommsVoice' in (ROOT / 'ForeverGroupComms/install/Install-ForeverGroupComms.ps1').read_text()
assert 'ForeverCommsVoice' in (ROOT / 'ForeverGuildComms/install/Install-ForeverGuildComms.ps1').read_text()
print('PASS: restore-defaults isolation, expressive punctuation and per-addon dependency installer checks')
