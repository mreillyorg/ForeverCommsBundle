#!/usr/bin/env python3
"""Validate the Forever Comms release bundle before publishing.

Run from the suite root, after BigWigsMods/packager or `python tools/package.py`:

    python tools/check_bigwigs_bundle.py [output-dir]      default: .release

Three groups of checks:

1. Archive structure -- the `move-folders` result. Exactly the three addon folders at top
   level with no stray files, each TOC present, both consumer dependency declarations
   intact, no tests/install/.github content.
2. Runtime completeness -- every file the client needs actually shipped, including
   `Bindings.xml`, which is auto-loaded from the addon root and deliberately absent from
   the TOC, so nothing in the TOC-driven checks would notice it missing.
3. Version consistency -- each addon's version agrees across all four places it is
   written, and the shipped TOC matches the repository.

Addon behaviour is NOT checked here; the workflow runs tools/run_tests.py before this.
"""
from pathlib import Path
import re
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parent.parent
ADDONS = ('ForeverCommsVoice', 'ForeverGuildComms', 'ForeverGroupComms')
CONSUMERS = ('ForeverGuildComms', 'ForeverGroupComms')


class BundleError(Exception):
    """A release-blocking problem with the bundle or its version metadata."""


def fail(message):
    raise BundleError(message)


def check(condition, message):
    """Explicit raise rather than `assert`, so `python -O` cannot skip a release gate."""
    if not condition:
        raise BundleError(message)


def toc_version(text, label):
    match = re.search(r'^## Version:\s*(\S+)', text, re.M)
    if not match:
        fail(f'{label} has no ## Version line')
    return match.group(1)


def check_versions():
    """Each addon states its version in four places. They must agree.

    This is the check that lets a release ship with a stale README or installer banner if
    it is not run, which is exactly what happened between 0.5.1 and 0.6.2.
    """
    versions = {}
    for addon in ADDONS:
        folder = ROOT / addon
        version = toc_version((folder / f'{addon}.toc').read_text(encoding='utf-8-sig'),
                              f'{addon}.toc')
        versions[addon] = version

        core = (folder / 'Core.lua').read_text(encoding='utf-8-sig')
        # Two forms are in use: `A.version = "x"` and `V.name, V.version = ADDON, "x"`.
        # Take the first quoted value on whichever line assigns .version.
        declared = re.search(r'^.*\.version\s*=.*?["\']([^"\']+)["\']', core, re.M)
        check(declared is not None, f'{addon}/Core.lua declares no version')
        check(declared.group(1) == version,
              f'{addon}: Core.lua says {declared.group(1)}, TOC says {version}')

        readme = folder / 'README.md'
        if readme.is_file() and version not in readme.read_text(encoding='utf-8'):
            fail(f'{addon}/README.md does not mention version {version}')

        launcher = folder / 'install' / f'Install-{addon}.cmd'
        if launcher.is_file() and version not in launcher.read_text(encoding='utf-8'):
            fail(f'{addon}/install/Install-{addon}.cmd does not mention version {version}')

        print(f'PASS: {addon} {version} consistent across TOC, Core.lua, README and installer')
    return versions


def expected_runtime(addon):
    """Files the client must receive, derived from the TOC plus the auto-loaded extras."""
    folder = ROOT / addon
    text = (folder / f'{addon}.toc').read_text(encoding='utf-8-sig')
    required = {f'{addon}/{addon}.toc'}
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith('## IconTexture:'):
            required.add(f'{addon}/Media/Icon.tga')
        if not line or line.startswith('#'):
            continue
        required.add(f'{addon}/{line}')
    # Auto-loaded from the addon root and deliberately NOT in the TOC. Without this check
    # a release could silently ship without key bindings.
    if (folder / 'Bindings.xml').is_file():
        required.add(f'{addon}/Bindings.xml')
    return required


def check_archive(path, versions):
    with zipfile.ZipFile(path) as arc:
        corrupt = arc.testzip()
        if corrupt:
            fail(f'corrupt {path}: {corrupt}')
        names = set(arc.namelist())

        files = {n for n in names if n and not n.endswith('/')}
        top = {n.split('/', 1)[0] for n in files}
        if top != set(ADDONS):
            extras = sorted(n for n in files if n.split('/', 1)[0] not in ADDONS)
            fail(f'{path}: expected only {sorted(ADDONS)} at top level; got {sorted(top)}'
                 + (f'; unexpected files: {extras[:12]}' if extras else ''))

        for member in files:
            if member.startswith('/') or '..' in Path(member).parts:
                fail(f'{path}: unsafe archive member {member}')

        for addon in ADDONS:
            missing = sorted(expected_runtime(addon) - names)
            if missing:
                fail(f'{path}: {addon} is missing runtime files: {", ".join(missing)}')

        for addon in CONSUMERS:
            toc = arc.read(f'{addon}/{addon}.toc').decode('utf-8-sig')
            if '## Dependencies: ForeverCommsVoice' not in toc:
                fail(f'{path}: broken ForeverCommsVoice dependency in {addon}')

        # The shipped TOC must be the one that was reviewed, not a rewritten copy.
        for addon in ADDONS:
            shipped = toc_version(arc.read(f'{addon}/{addon}.toc').decode('utf-8-sig'),
                                  f'{addon}.toc in {path.name}')
            if shipped != versions[addon]:
                fail(f'{path}: {addon} ships version {shipped}, repository says '
                     f'{versions[addon]}')

        for member in names:
            if '/tests/' in member or '/install/' in member or '/.github/' in member:
                fail(f'{path}: non-runtime content {member}')

    print(f'PASS: {path.name} ({len(names)} entries)')


def check_publish_pkgmeta():
    """Each addon publishes to its own CurseForge project from this monorepo.

    release.sh needs a .git directory at its topdir, so it cannot be aimed at one addon
    folder; topdir is the repository root and the entire root is copied into the package
    directory. Everything that is not the addon being published therefore has to be named
    in that addon's ignore list, and a file added to the repository root would otherwise
    be published inside all three addons without anyone noticing.

    So assert completeness here, before any upload: every top-level entry except the
    addon's own folder must be ignored.
    """
    top = subprocess.run(['git', 'ls-tree', '--name-only', 'HEAD'], cwd=ROOT,
                         capture_output=True, text=True)
    if top.returncode != 0:
        print('NOTE: not a git checkout, skipping publish .pkgmeta completeness check')
        return
    entries = {line.strip() for line in top.stdout.splitlines() if line.strip()}
    for addon in ADDONS:
        path = ROOT / 'tools' / 'pkgmeta' / f'{addon}.yaml'
        check(path.is_file(), f'missing publish config {path.relative_to(ROOT)}')
        text = path.read_text(encoding='utf-8')
        ignored = {line.strip()[2:].strip() for line in text.splitlines()
                   if line.strip().startswith('- ')}
        if f'package-as: {addon}' not in text:
            fail(f'{path.name} must declare "package-as: {addon}"')
        missing = sorted(e for e in entries if e != addon and e not in ignored)
        if missing:
            fail(f'{path.name} does not ignore {missing}. Everything at the repository '
                 f'root except {addon} must be ignored, or it ships inside the published '
                 f'addon.')
        if addon in ignored:
            fail(f'{path.name} ignores {addon}, the addon it is supposed to publish')
        print(f'PASS: {path.name} excludes every root entry except {addon}')


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / '.release'
    if not out.is_absolute():
        out = ROOT / out
    check_publish_pkgmeta()
    versions = check_versions()
    archives = sorted(out.glob('*.zip'))
    if not archives:
        fail(f'no *.zip found in {out}. Build first with BigWigs or tools/package.py')
    for path in archives:
        check_archive(path, versions)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, BundleError, zipfile.BadZipFile) as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        sys.exit(1)
