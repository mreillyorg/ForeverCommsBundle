#!/usr/bin/env python3
"""Verify suite packaging without a WoW client, GitHub or external libraries.

Scope: packaging only. Archive membership, dependency bundling, installer
presence and version/README agreement.

Addon *behaviour* is not checked here. It is asserted by the 13 offline Lua
harnesses, which the workflow runs before this step via tools/run_tests.py.
Earlier revisions grepped Lua source from this file to prove two specific fixes
were present; that coupled release packaging to the exact text and indentation
of two Lua functions, and is now redundant:
  - GuildComms Restore Defaults isolation -> ForeverGuildComms/tests/settings.lua
  - Expressive terminal-period conversion -> ForeverCommsVoice/tests/integration.lua

Explicit raises rather than bare asserts, so `python -O` cannot skip the checks.
"""
from pathlib import Path
import re
import sys
import zipfile

ROOT = Path(__file__).resolve().parent.parent
ADDONS = ('ForeverCommsVoice', 'ForeverGuildComms', 'ForeverGroupComms')


class VerificationError(Exception):
    pass


def check(condition, message):
    if not condition:
        raise VerificationError(message)


def addon_versions():
    versions = {}
    for addon in ADDONS:
        toc = (ROOT / addon / (addon + '.toc')).read_text(encoding='utf-8-sig')
        match = re.search(r'^## Version:\s*(\S+)', toc, re.M)
        check(match is not None, f'{addon}.toc has no ## Version line')
        versions[addon] = match.group(1)
        expected_icon = f'## IconTexture: Interface\\AddOns\\{addon}\\Media\\Icon'
        check(expected_icon in toc, f'{addon}.toc is missing or misdeclares {expected_icon}')
        check((ROOT / addon / 'Media/Icon.tga').exists(), f'{addon} is missing Media/Icon.tga')
        check((ROOT / addon / 'Media/ProjectIcon.png').exists(),
              f'{addon} is missing Media/ProjectIcon.png')
        # Guards the version-drift case the TOC and Core.lua cannot catch alone.
        readme = (ROOT / addon / 'README.md').read_text(encoding='utf-8')
        check(versions[addon] in readme,
              f'{addon}/README.md does not mention version {versions[addon]}')
    return versions


def expected_addons(scope):
    if scope == 'suite':
        return ADDONS
    if scope == 'ForeverCommsVoice':
        return (scope,)
    # A consumer archive must carry its dependency so its installer can order them.
    return ('ForeverCommsVoice', scope)


def verify_archive(zip_path, scope):
    check(zip_path.is_file(), f'Missing archive: {zip_path}')
    with zipfile.ZipFile(zip_path) as archive:
        names = set(archive.namelist())
        check(archive.testzip() is None, f'Corrupt archive: {zip_path}')
        check('install/Install-ForeverComms.ps1' in names,
              f'{zip_path.name} is missing the shared installer')
        for addon in expected_addons(scope):
            for member in (f'{addon}/{addon}.toc',
                           f'{addon}/Media/Icon.tga',
                           f'{addon}/Media/ProjectIcon.png',
                           f'{addon}/install/Install-{addon}.ps1'):
                check(member in names, f'{zip_path.name} is missing {member}')
        if scope == 'suite':
            for member in ('.github/workflows/package.yml', 'tools/package.py',
                           'tools/run_tests.py', 'tools/verify_package.py',
                           'package.ps1', 'package.cmd', 'run-tests.cmd', 'PACKAGING.md'):
                check(member in names, f'Suite archive is missing {member}')
        else:
            check(f'{scope}/install/Install-{scope}.cmd' in names,
                  f'{zip_path.name} is missing {scope}/install/Install-{scope}.cmd')
        for member in names:
            check(not (member.startswith('/') or '..' in Path(member).parts),
                  f'{zip_path.name} contains an unsafe member: {member}')
    return len(names)


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'dist'
    versions = addon_versions()
    archives = {addon: f'{addon}-{versions[addon]}.zip' for addon in ADDONS}
    archives['suite'] = f'ForeverComms-Bundle-{versions["ForeverGuildComms"]}.zip'
    for scope, name in archives.items():
        count = verify_archive(out / name, scope)
        print(f'PASS: {name} ({count} members)')
    print('PASS: versions, icons, dependency bundling, installer presence and member safety')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, VerificationError) as exc:
        print(f'Verification failed: {exc}', file=sys.stderr)
        sys.exit(1)
